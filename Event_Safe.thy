theory Event_Safe
  imports Aux_for_CSL Event_Helper
begin

primrec update_list_env :: "(rname \<Rightarrow> assn) \<Rightarrow> (rname \<times> assn) list \<Rightarrow> (rname \<Rightarrow> assn)"
  where "update_list_env \<Gamma> [] = \<Gamma>"
  | "update_list_env \<Gamma> (x # xs) = update_list_env (\<Gamma> (fst x := snd x)) xs"

subsection \<open>specification and proof rules for events\<close>
primrec
  esafe :: "nat \<Rightarrow> event \<Rightarrow> stack \<Rightarrow> heap \<Rightarrow> (rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> bool"
where
  "esafe 0 e s h \<Gamma> Q = True"
| "esafe (Suc n) e s h \<Gamma> Q = (
  (e = AnonyEvent Cskip \<longrightarrow> (s, h) \<Turnstile> Q)
\<and> (\<forall>hF. disjoint (dom h) (dom hF) \<longrightarrow> \<not> eaborts e (s, h ++ hF))
\<and> (eaccesses e s \<subseteq> dom h)
\<and> (\<forall>hJ hF e' \<sigma>' x x' actk. 
        (e, (s, h ++ hJ ++ hF), x) -et-actk\<rightarrow> (e', \<sigma>', x')
    \<longrightarrow> (s, hJ) \<Turnstile> envs \<Gamma> (ellocked e') (ellocked e)
    \<longrightarrow> (disjoint (dom h) (dom hJ) \<and> disjoint (dom h) (dom hF) \<and> disjoint (dom hJ) (dom hF))
    \<longrightarrow> (\<exists> h' hJ'.
            snd \<sigma>' = h' ++ hJ' ++ hF
          \<and> disjoint (dom h') (dom hJ') \<and> disjoint (dom h') (dom hF) \<and> disjoint (dom hJ') (dom hF)
          \<and> (fst \<sigma>', hJ') \<Turnstile> envs \<Gamma> (ellocked e) (ellocked e')
          \<and>  esafe n e' (fst \<sigma>') h' \<Gamma> Q)))"

lemma esafe_mon:
  "\<lbrakk> esafe n e s h \<Gamma> Q; m \<le> n \<rbrakk> \<Longrightarrow> esafe m e s h \<Gamma> Q"
apply (induct m arbitrary: e s n h, simp) 
apply (case_tac n, clarify)
  apply (simp only: safe.simps, clarsimp)
  apply (drule_tac a = hJ and b = hF and c = e' and d = a and e = b in all5D)
  apply (drule imp3D, simp_all)
   apply blast
  apply (clarsimp, rule_tac x="h'" in exI, rule_tac x="hJ'" in exI, simp)
  done

lemma esafe_agrees: 
    "\<lbrakk> esafe n e s h \<Gamma> Q ; 
     agrees (fvEv e \<union> fvA Q \<union> fvAs \<Gamma>) s s' \<rbrakk>
   \<Longrightarrow> esafe n e s' h \<Gamma> Q"
  apply (induct n arbitrary: e s s' h, simp, simp only: esafe.simps, clarify)
  apply (rule conjI, clarsimp, subst assn_agrees, subst agreesC, assumption+)
  apply (rule conjI, clarsimp)
   apply (drule_tac eaborts_agrees, simp, fast, simp, simp)
  apply (rule conjI, subst(asm) eaccesses_agrees, simp_all)
  apply (clarify, drule_tac X="fvEv e \<union> fvAs \<Gamma> \<union> fvA Q" in ered_agrees, 
         simp (no_asm), fast, simp (no_asm), fast, clarify)
  apply (drule_tac a = hJ and b = hF and c = e' and d = s'a and e = b in all5_impD)
  apply auto[1]
  apply (drule imp2D)
  using assns_agrees apply blast
  apply force
  apply (clarsimp, rule_tac x=h' and y=hJ' in ex2I, simp add: hsimps)
  apply (rule conjI, erule assns_agreesE, subst agreesC, assumption)
  apply (erule (1) mall4_imp2D, simp add: agreesC)
  apply (drule ered_properties, auto)
  done

definition 
  eCSL :: "(rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> event \<Rightarrow> assn \<Rightarrow> bool" 
  ("_ \<turnstile>\<^sub>e { _ } _ { _ }")
  where
    "\<Gamma> \<turnstile>\<^sub>e {P} e {Q} \<equiv> (user_event e) \<and> (\<forall>n s h. (s, h) \<Turnstile> P \<longrightarrow> esafe n e s h \<Gamma> Q)"


lemma list_minus_empty[simp] : "list_minus [] l = []"
  by (induct l, simp_all)

lemma envs_empty_minus[simp]: " envs \<Gamma> [] l = Aemp"
  by (simp add: envs_def)

lemma envs_minus_empty[simp]: " envs \<Gamma> l [] = Aistar (map \<Gamma> l)"
  by (simp add: envs_def)

lemma esafe_conseq : "\<lbrakk> esafe n e s h \<Gamma> Q; Q \<sqsubseteq> Q'\<rbrakk> \<Longrightarrow> esafe n e s h \<Gamma> Q'"
  apply (induct n arbitrary: e s h, simp)
  apply (clarsimp, simp add : implies_def)
  apply (clarify, erule ered.cases, simp_all, clarsimp)
   apply (drule_tac a = "hJ" and b = "hF" and c = "AnonyEvent C'" 
          and d = "a" and e = "b" in all5_impD)
    apply (metis ered.red_AnonyEvt)
   apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp)
  apply (drule_tac a = "hJ" and b = "hF" and c = "AnonyEvent C" 
          and d = "s" and e = "h ++ hJ ++ hF" in all5_impD)
  apply (metis ered.red_BasicEvt fst_conv)
  apply (clarsimp, rule_tac x = "h'" in exI, simp)
  done

theorem rule_Evtconseq : "\<lbrakk> \<Gamma> \<turnstile>\<^sub>e {P} e {Q};  P' \<sqsubseteq> P; Q \<sqsubseteq> Q'\<rbrakk> \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>e {P'} e {Q'}"
  by (meson eCSL_def esafe_conseq implies_def)

theorem rule_Evt_equiv : "\<lbrakk> \<Gamma> \<turnstile>\<^sub>e {P} e {Q};  P' \<equiv>\<^sub>S\<^sub>L P; Q \<equiv>\<^sub>S\<^sub>L Q'\<rbrakk> \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>e {P'} e {Q'}"
  using equiv_implies rule_Evtconseq by blast

lemma esafe_AnonyEvt: "safe n C s h \<Gamma> Q \<Longrightarrow> esafe n (AnonyEvent C) s h \<Gamma> Q"
  apply (induct n arbitrary: C s h, simp, clarsimp)
  apply (rule conjI)
  using eaborts.cases apply blast
  apply (clarsimp, erule ered.cases, simp_all)
  apply (drule_tac a = "hJ" and b = "hF" and c = "C'" and d = "a " and e = "b" in all5_impD, simp)
  apply (drule imp2D, simp_all)
  by blast

theorem rule_Inner: "\<Gamma> \<turnstile> {P} C {Q} \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>e {P} (AnonyEvent C) {Q}"
  by (simp add: eCSL_def CSL_def esafe_AnonyEvt)

lemma esafe_BasicEvt : "\<forall>n s h. (s, h) \<Turnstile> P \<and> bdenot guard s \<longrightarrow> safe n C s h \<Gamma> Q \<Longrightarrow>
       (s, h) \<Turnstile> P \<Longrightarrow> user_cmd C \<Longrightarrow> esafe n (BasicEvent (guard, C)) s h \<Gamma> Q"
  apply (case_tac n, simp, simp)
  apply (rule conjI)
  using eaborts.cases apply blast
  apply (clarsimp, erule ered.cases, simp)
  apply (rule_tac x = "h" in exI, clarify, simp add: esafe_AnonyEvt)
  done

theorem rule_BasicEvt: "\<Gamma> \<turnstile> {Aconj P (Apure guard)} C {Q} 
                    \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>e {P} (BasicEvent (guard, C)) {Q}"
  apply (simp add: eCSL_def CSL_def, clarify)
  by (simp add: esafe_BasicEvt)

corollary rule_BasicEvt_true : "\<Gamma> \<turnstile> {P} C {Q} 
                    \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>e {P} (BasicEvent ([True]\<^sub>b, C)) {Q}"
  apply (rule rule_BasicEvt, rule rule_conseq, simp_all)
  by (simp_all add: implies_def)

lemma esafe_frame:
 "\<lbrakk> esafe n e s h J Q; 
    disjoint (dom h) (dom hR);
    disjoint (fvA R) (wrEv e);
    (s,hR) \<Turnstile> R\<rbrakk>
  \<Longrightarrow> esafe n e s (h ++ hR) J (Q ** R)"
  apply (induct n arbitrary: e s h hR, simp, clarsimp)
  apply (rule conjI, clarify, fast)
  apply (rule conjI, clarify)
 (* no aborts *)
   apply (drule_tac a="hR ++ hF" in all_impD, simp, simp add: hsimps)
(* accesses *)
  apply (rule conjI, erule order_trans, simp)
(* step *)
  apply (clarify, frule ered_properties, clarsimp)
  apply (drule_tac a="hJ" and b="hR ++ hF" and c = e' and d = a and e = b in all5D)
  apply (drule imp3D)
    apply (metis map_add_assoc map_add_commute)
    apply force
   apply force
  apply (clarsimp, rule_tac y="hJ'" and x="h' ++ hR" in ex2I, clarsimp simp add: hsimps)
  apply (subst map_add_commute, simp add: hsimps)
  apply (drule mall4D, erule mimp4D, simp_all add: hsimps)
   apply (erule (1) disjoint_search)
  apply (subst assn_agrees, simp_all, fastforce)
  done


theorem erule_frame:
 "\<lbrakk> \<Gamma> \<turnstile>\<^sub>e {P} e {Q} ; disjoint (fvA R) (wrEv e) \<rbrakk>
  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>e {P ** R} e {Q ** R}"
  by (auto simp add: eCSL_def intro: esafe_frame)

subsection \<open>specification and proof rules for resource events\<close>

primrec 
  resafe :: "nat \<Rightarrow> revent \<Rightarrow> stack \<Rightarrow> heap \<Rightarrow> (rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> bool"
where
  "resafe 0 e s h \<Gamma> Q = True"
| "resafe (Suc n) re s h \<Gamma> Q = (
  (snd re = AnonyEvent Cskip \<longrightarrow> (s, h) \<Turnstile> Q)
\<and> (\<forall>hF. disjoint (dom h) (dom hF) \<longrightarrow> \<not> reaborts re (s, h ++ hF))
\<and> (reaccesses re s \<subseteq> dom h)
\<and> (\<forall>hJ hF re' \<sigma>' x x' actk. 
      (re, (s, h ++ hJ ++ hF), x) -ret-actk\<rightarrow> (re', \<sigma>', x')
    \<longrightarrow> (s, hJ) \<Turnstile> envs \<Gamma> (rellocked re') (rellocked re)
    \<longrightarrow> (disjoint (dom h) (dom hJ) \<and> disjoint (dom h) (dom hF) \<and> disjoint (dom hJ) (dom hF))
    \<longrightarrow> (\<exists>h' hJ'.
            snd \<sigma>' = h' ++ hJ' ++ hF
          \<and> disjoint (dom h') (dom hJ') \<and> disjoint (dom h') (dom hF) \<and> disjoint (dom hJ') (dom hF)
          \<and> (fst \<sigma>', hJ') \<Turnstile> envs \<Gamma> (rellocked re) (rellocked re')
          \<and> resafe n re' (fst \<sigma>') h' \<Gamma> Q)))"

lemma resafe_mon:
  "\<lbrakk> resafe n re s h \<Gamma> Q; m \<le> n \<rbrakk> \<Longrightarrow> resafe m re s h \<Gamma> Q"
apply (induct m arbitrary: re s n h, simp) 
apply (case_tac n, clarify)
apply (simp only: safe.simps, clarsimp)
  apply (drule_tac a = hJ and b = hF and c = aa and d = ba and e = ab and f = bb in all6D, drule imp3D, simp_all)
   apply blast
  apply (clarsimp, rule_tac x="h'" in exI, rule_tac x="hJ'" in exI, simp)
  done 

lemma resafe_agrees: 
    "\<lbrakk> resafe n re s h \<Gamma> Q ; 
     agrees (fvREv re \<union> fvA Q \<union> fvAs \<Gamma>) s s' \<rbrakk>
   \<Longrightarrow> resafe n re s' h \<Gamma> Q"
  apply (induct n arbitrary: re s s' h, simp, simp only: resafe.simps, clarify)
  apply (rule conjI, clarsimp, subst assn_agrees, subst agreesC, assumption+)
  apply (rule conjI, clarsimp)
   apply (drule_tac reaborts_agrees, simp, fast, simp, simp)
  apply (rule conjI, subst (asm) reaccesses_agrees, simp_all)
  apply (clarify, drule_tac X = "fvREv (a, b) \<union> fvAs \<Gamma> \<union> fvA Q" in rered_agrees,
       simp (no_asm), fast, simp(no_asm), fast, clarify)
  apply (drule_tac a = hJ and b = hF and c = aa and d = ba and e = s'a and f = bb in all6D, simp_all)
  apply (drule imp2D)
    apply blast
   apply (metis assns_agrees)
  apply (clarsimp, rule_tac x=h' and y=hJ' in ex2I, simp add: hsimps)
  apply (rule conjI, erule assns_agreesE, subst agreesC, assumption)
  apply (erule (1) mall5_imp2D, simp add: agreesC)
  apply (drule rered_properties, auto)
  done

definition 
  reCSL :: "(rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> revent \<Rightarrow> assn \<Rightarrow> bool" 
  ("_ \<turnstile>\<^sub>r\<^sub>e { _ } _ { _ }")
  where
    "\<Gamma> \<turnstile>\<^sub>r\<^sub>e {P} re {Q} \<equiv> (user_revent re) \<and> (\<forall>n s h. (s, h) \<Turnstile> P \<longrightarrow> resafe n re s h \<Gamma> Q)"

lemma resafe_conseq : "\<lbrakk> resafe n re s h \<Gamma> Q; Q \<sqsubseteq> Q'\<rbrakk> \<Longrightarrow> resafe n re s h \<Gamma> Q'"
    apply (induct n arbitrary: re s h, simp)
  apply (clarsimp, simp add : implies_def)
  apply (clarify, erule rered.cases, simp_all, clarsimp)
   apply (drule_tac a = "hJ" and b = "hF" and c = "a" and d = "AnonyEvent C'" 
          and e = "ab" and f = "bb" in all6_impD)
    apply (metis rered.red_AnonyEvt)
   apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp)
  apply (drule_tac a = "hJ" and b = "hF" and c = "a" and d = "AnonyEvent C" 
         and e = "s" and f = "h ++ hJ ++ hF" in all6_impD)
   apply (metis fst_conv rered.red_BasicEvt)
  apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp)
  done

theorem rule_rEvtconseq : "\<lbrakk>\<Gamma> \<turnstile>\<^sub>r\<^sub>e {P} re {Q} ; P' \<sqsubseteq> P; Q \<sqsubseteq> Q' \<rbrakk> \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>r\<^sub>e {P'} re {Q'}"
  by (meson implies_def reCSL_def resafe_conseq)

theorem rule_re_equiv: "\<lbrakk> \<Gamma> \<turnstile>\<^sub>r\<^sub>e {P} re {Q}; P \<equiv>\<^sub>S\<^sub>L P'; Q \<equiv>\<^sub>S\<^sub>L Q' \<rbrakk> \<Longrightarrow>  \<Gamma> \<turnstile>\<^sub>r\<^sub>e {P'} re {Q'}"
  by (simp add: assn_equiv_symmetry equiv_implies rule_rEvtconseq)

lemma resafe_res:
 "\<lbrakk>resafe n (rs, e) s h (\<Gamma>(r := R)) Q; wf_revent (rs, e); r \<notin> set rs;
   disjoint (fvA R) (wrREv (rs, e)) \<rbrakk> \<Longrightarrow> (\<forall>hR. r \<notin> relocked (rs, e) \<longrightarrow> disjoint (dom h) (dom hR) 
     \<longrightarrow> (s,hR) \<Turnstile> R \<longrightarrow> resafe n (r # rs, e) s (h ++ hR) \<Gamma> (Q ** R))
   \<and> (r \<in> relocked (rs, e) \<longrightarrow> resafe n (r # rs, e) s h \<Gamma> (Q ** R))"
  apply (induct n arbitrary: e s h, simp, clarsimp)
  apply (rule conjI, clarify)
   apply (rule conjI) apply auto[1]
  apply (rule conjI)
    apply (metis disjoint_simps(4) dom_map_add map_add_assoc reaborts.simps snd_conv)
   apply (rule conjI, simp add: le_supI2 reaccesses_def)
   apply (clarify, frule rered_properties, clarsimp)
   apply (subgoal_tac "a = r # rs", simp)
    apply (case_tac "r \<in> set (rellocked (rs, b))", simp add: rellocked_def)
  apply (drule_tac a = "hJ ++ hR" and b = "hF" and c = rs and d = b and e = aa
          and f = "ba" in all6_impD, simp add: hsimps)
  apply (meson re_equiv3)
     apply (drule imp2D, subst sat_envs_expand [where r=r], simp_all add: relocked_def elocked_eq)
       apply (subgoal_tac "wf_revent (r # rs, e)")
        apply (subgoal_tac "wf_revent (a, b)", simp add: wf_revent_def)
         apply (simp add: distinct_list_minus wf_event_distinct_locked) 
        apply (simp add: red_wf_revent, simp add: wf_revent_def)
      apply (intro exI conjI, simp, simp_all add: envs_upd hsimps relocked_def)
     apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp add: envs_removeAll_irr)
     apply (drule (1) mall3_imp2D)
  using red_wf_revent re_equiv3 apply blast
     apply (simp add: relocked_def elocked_eq, drule mimpD)
      apply (meson disjoint_search(4) re_equiv3 rered_properties, simp)
    apply (drule_tac a="hJ" and b="hR ++ hF" and c = rs and d = b and e = aa
          and f = "ba" in all6_impD, simp add: hsimps)
  using re_equiv3 apply blast
    apply (drule imp2D, simp add: rellocked_def envs_upd(1)) apply auto[1]
apply (clarsimp, rule_tac x = "h' ++ hR" and y = "hJ'" in ex2I, simp add: hsimps)
    apply (rule conjI, simp add: envs_upd(1) rellocked_def relocked_eq)
     apply (drule (1) mall3_imp2D)
  using red_wf_revent re_equiv3 apply blast
    apply (drule mimpD)
     apply (meson disjoint_search(1) disjoint_search(2) re_equiv3 rered_properties)
    apply (simp add: rellocked_def elocked_def)
    apply (drule_tac a = "hR" in all_imp2D)
  using disjoint_commute apply blast
     apply (metis agrees_minusD assn_agrees disjoint_commute snd_eqD wrREv_def)

    apply (simp add: map_add_commute)
  using rered.simps apply auto[1]
  apply (clarsimp, rule conjI) apply auto[1]
  apply (rule conjI, simp add: reaborts_equiv)
  apply (rule conjI, simp add: reaccesses_def)
  apply (clarify, frule rered_properties, clarsimp)
  apply (subgoal_tac "a = r # rs", simp)
    apply (drule_tac a="hJ" and b=" hF" and c = rs and d = b and e = aa
          and f = "ba" in all6_impD)
  using re_equiv3 apply blast
   apply (drule imp2D, simp add: envs_removeAll2 envs_upd(2) rellocked_def elocked_eq, simp)
   apply (clarsimp, drule (1) mall3_imp2D)
  using red_wf_revent re_equiv3 apply blast
   apply (drule mimpD, meson disjoint_search(4) re_equiv3 rered_properties)
   apply (case_tac "r \<in> set (rellocked (rs, b))", simp add: rellocked_def)
    apply (intro exI conjI, simp+)
     apply (simp add: envs_removeAll2 envs_upd(2), simp add: relocked_def elocked_eq)
  apply (subst (asm) sat_envs_expand [where r=r]) back
      apply (simp_all add: rellocked_def relocked_def elocked_eq)
    apply (simp add: wf_revent_def)
  using distinct_list_minus wf_event_distinct_locked apply blast
   apply (clarsimp, drule (2) all_imp2D, rule_tac x = "h' ++ h1" and y = " h2" in ex2I, 
        simp add: hsimps envs_upd)
  by (metis fst_conv re_invres)

lemma resafe_res_empty : "esafe n e s h \<Gamma> Q \<Longrightarrow> resafe n ([], e) s h \<Gamma> Q"
  apply (induct n arbitrary: e s h, simp, clarsimp)
  apply (rule conjI, simp add: reaborts_equiv)
  apply (rule conjI, simp add: reaccesses_def, clarsimp)
  apply (subgoal_tac "a = []", simp)
   apply (drule_tac a = "hJ" and b = "hF" and c = "b" and d = "aa" and e = "ba" in all5_impD)
  apply (meson re_equiv2)
    apply (drule imp2D, simp add: rellocked_def, simp, clarsimp)
   apply (rule_tac x = h' and y = hJ' in ex2I, simp add: rellocked_def)
  by (metis fst_conv re_invres)

theorem rule_re_empty : "\<Gamma> \<turnstile>\<^sub>e { P } e { Q } \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>e { P } ([], e) { Q }"
  by (simp add: eCSL_def reCSL_def user_revent_def resafe_res_empty)

lemma rule_re1 : "\<lbrakk> \<Gamma>(r := R) \<turnstile>\<^sub>r\<^sub>e {P} (rs, e) {Q} ; disjoint (fvA R) (wrREv (rs, e)); r \<notin> set rs \<rbrakk> 
  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>e  {P ** R} (r # rs, e) {Q ** R}"
  apply (clarsimp simp add: reCSL_def)
  apply (rule conjI, simp add: user_revent_def, clarsimp)
  apply (drule_tac a = n and b = s and c = h1 in all3_impD, simp)
  by (simp add: resafe_res user_reventD)

theorem rule_re : 
    "\<lbrakk>(update_list \<Gamma> \<G> rs) \<turnstile>\<^sub>e {P} e {Q} ;disjoint (fvA (Aistar (map \<G> rs))) (wrEv e); distinct rs\<rbrakk> 
    \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>e {P ** (Aistar (map \<G> rs))} (rs, e) {Q ** (Aistar (map \<G> rs))}"
  apply (induct rs arbitrary: \<Gamma>, rule_tac P = "P" and Q = "Q" in rule_re_equiv)
     apply (simp add: rule_re_empty, simp, simp add: assn_equiv_def, simp add: assn_equiv_def)
  apply (drule_tac a = "\<Gamma>(a := \<G> a)" in mall_impD, clarsimp)
  apply (rule_tac P = "(P ** Aistar (map \<G> rs)) ** \<G> a" and Q = "(Q ** Aistar (map \<G> rs)) ** \<G> a"
  in rule_re_equiv, rule rule_re1, simp, simp add: wrREv_def, simp)
   apply (meson Aistar_equiv) apply (meson Aistar_equiv)
  done

lemma resafe_frame:
 "\<lbrakk> resafe n re s h J Q; 
    disjoint (dom h) (dom hR);
    disjoint (fvA R) (wrREv re);
    (s,hR) \<Turnstile> R\<rbrakk>
  \<Longrightarrow> resafe n re s (h ++ hR) J (Q ** R)"
  apply (induct n arbitrary: re s h hR, simp, clarsimp)
  apply (rule conjI, clarify, fast)
  apply (rule conjI, clarify)
 (* no aborts *)
   apply (drule_tac a="hR ++ hF" in all_impD, simp, simp add: hsimps)
(* accesses *)
  apply (rule conjI, erule order_trans, simp)
(* step *)
  apply (clarify, frule rered_properties, clarsimp)
  apply (drule_tac a="hJ" and b="hR ++ hF" and c = aa and d = ba and e = ab and f = bb in all6D)
  apply (drule imp3D, simp_all)
    apply (metis map_add_assoc map_add_commute)
  apply force
  apply (clarsimp, rule_tac y="hJ'" and x="h' ++ hR" in ex2I, clarsimp simp add: hsimps)
  apply (subst map_add_commute, simp add: hsimps)
  apply (drule mall5D, erule mimp4D, simp_all add: hsimps)
 apply (erule (1) disjoint_search)
  apply (subst assn_agrees, simp_all, fastforce)
  done


theorem rerule_frame:
 "\<lbrakk> \<Gamma> \<turnstile>\<^sub>r\<^sub>e {P} re {Q} ; disjoint (fvA R) (wrREv re) \<rbrakk>
  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>e {P ** R} re {Q ** R}"
  by (auto simp add: reCSL_def intro: resafe_frame)

subsection \<open>specification and proof rules for event systems\<close>

primrec 
  essafe :: "nat \<Rightarrow> esys \<Rightarrow> stack \<Rightarrow> heap \<Rightarrow> (rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> bool"
where
  "essafe 0 es s h \<Gamma> Q = True"
| "essafe (Suc n) es s h \<Gamma> Q = (
 (\<forall>hF. disjoint (dom h) (dom hF) \<longrightarrow> \<not> esaborts es (s, h ++ hF))
\<and> (esaccesses es s \<subseteq> dom h)
\<and> (\<forall>hJ hF es' \<sigma>' x x' actk. 
      (es, (s, h ++ hJ ++ hF), x) -es-actk\<rightarrow> (es', \<sigma>', x')
    \<longrightarrow> (s, hJ) \<Turnstile> envs \<Gamma> (esllocked es') (esllocked es)
    \<longrightarrow> (disjoint (dom h) (dom hJ) \<and> disjoint (dom h) (dom hF) \<and> disjoint (dom hJ) (dom hF))
    \<longrightarrow> (\<exists>h' hJ'.
            snd \<sigma>' = h' ++ hJ' ++ hF
          \<and> disjoint (dom h') (dom hJ') \<and> disjoint (dom h') (dom hF) \<and> disjoint (dom hJ') (dom hF)
          \<and> (fst \<sigma>', hJ') \<Turnstile> envs \<Gamma> (esllocked es) (esllocked es')
          \<and> essafe n es' (fst \<sigma>') h' \<Gamma> Q)))"

lemma essafe_agrees: 
    "\<lbrakk> essafe n esys s h \<Gamma> Q ; 
     agrees (fvEsv esys \<union> fvA Q \<union> fvAs \<Gamma>) s s' \<rbrakk>
   \<Longrightarrow> essafe n esys s' h \<Gamma> Q"
  apply (induct n arbitrary: esys s s' h, simp, simp only: essafe.simps, clarify)
  apply (rule conjI, clarsimp)
   apply (drule_tac esaborts_agrees, simp, fast, simp, simp)
  apply (rule conjI, subst (asm) esaccesses_agrees, simp_all)
  apply (clarify, drule_tac X = "fvEsv esys \<union> fvAs \<Gamma> \<union> fvA Q" in esred_agrees,
       simp (no_asm), fast, simp(no_asm), fast, clarify)
  apply (drule_tac a = hJ and b = hF and c = es' and d = s'a and e = b in all5_impD)
  apply (metis snd_conv)
  apply (drule imp2D, erule assns_agreesE, simp add: agreesC, clarify)
  apply (clarsimp, rule_tac x=h' and y=hJ' in ex2I, simp add: hsimps)
  apply (rule conjI, erule assns_agreesE, subst agreesC, assumption)
  apply (erule (1) mall4_imp2D, simp add: agreesC)
  apply (drule esred_properties, auto)
  done

definition 
  esCSL :: "(rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> esys \<Rightarrow> assn \<Rightarrow> bool" 
  ("_ \<turnstile>\<^sub>e\<^sub>s { _ } _ { _ }")
  where
    "\<Gamma> \<turnstile>\<^sub>e\<^sub>s {P} esys {Q} \<equiv> (user_esys esys) \<and> (\<forall>n s h. (s, h) \<Turnstile> P \<longrightarrow> essafe n esys s h \<Gamma> Q)"

lemma essafe_mon:
  "\<lbrakk> essafe n es s h \<Gamma> Q; m \<le> n \<rbrakk> \<Longrightarrow> essafe m es s h \<Gamma> Q"
apply (induct m arbitrary: es s n h, simp) 
apply (case_tac n, clarify)
apply (simp only: safe.simps, clarsimp)
  apply (drule_tac a = hJ and b = hF and c = es' and d = a and e = b in all5D)
  apply (drule imp3D, simp_all)
  apply blast
  apply (clarsimp, rule_tac x="h'" in exI, rule_tac x="hJ'" in exI, simp)
  done

lemma essafe_conseq : "\<lbrakk> essafe n es s h \<Gamma> Q; Q \<sqsubseteq> Q'\<rbrakk> \<Longrightarrow> essafe n es s h \<Gamma> Q'"
  apply (induct n arbitrary: es s h, simp)
  apply (clarsimp, simp add : implies_def)
  apply (erule esred.cases, simp_all, clarify)
    apply (drule_tac a = "hJ" and b = "hF" and c = "EvtSeq (ab, bb) res" 
          and d = "a" and e = "b" in all5_impD)
     apply (metis esred.red_EvtSeq1)
    apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp)
   apply (drule_tac a = "hJ" and b = "hF" and c = "es'" and d = "a" and e = "b" in all5_impD)
    apply (metis esred.red_EvtSeq2)
   apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp)
  apply (drule_tac a = "hJ" and b = "hF" and c = "EvtSeq re' (EvtSys revts)" and d = "a" 
        and e = "b" in all5_impD)
   apply (metis esred.red_EvtSet)
  apply (clarsimp, rule_tac x = "h'" in exI, simp)
  done

theorem rule_esconseq : "\<lbrakk>\<Gamma> \<turnstile>\<^sub>e\<^sub>s {P} es {Q};  P' \<sqsubseteq> P; Q \<sqsubseteq> Q' \<rbrakk> \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>e\<^sub>s {P'} es {Q'}"
  by (meson esCSL_def essafe_conseq implies_def)

theorem rule_es_equiv : "\<lbrakk>\<Gamma> \<turnstile>\<^sub>e\<^sub>s {P} es {Q};  P' \<equiv>\<^sub>S\<^sub>L P; Q \<equiv>\<^sub>S\<^sub>L Q' \<rbrakk> \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>e\<^sub>s {P'} es {Q'}"
  using equiv_implies rule_esconseq by blast

(*
lemma essafe_EvtSeq :"\<lbrakk>resafe n re s h \<Gamma> Q;
        \<forall>m s' h'. m \<le> n \<and> (s', h') \<Turnstile> (Q ** (Aistar (map \<Gamma> (esllocked esys)))) 
                \<longrightarrow> essafe m esys s' h' \<Gamma> R\<rbrakk> 
      \<Longrightarrow>  essafe n (EvtSeq re esys) s h \<Gamma> R"
  apply (induct n arbitrary: re s h, simp, clarsimp)
  apply (rule conjI, clarsimp)
   apply (erule esaborts.cases, simp_all, clarsimp)
  apply (clarsimp, erule esred.cases, simp_all)
   apply (clarify, drule_tac a = hJ and b = hF and c = ac and d = bc and e = aa and f= ba in all6_impD)
    apply blast
   apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp)
  apply (clarify, simp add: rellocked_def)
  apply (drule_tac a = Map.empty and b = "hJ ++hF" and c = ac and d = "AnonyEvent Cskip" and e = aa and f= ba in all6_impD)
   apply (metis empty_map_add map_add_assoc, simp, clarsimp)
  apply (rule_tac x = "h' ++ hJ" and y = "hJ'" in ex2I, simp)
  apply (rule conjI)
  apply (metis map_add_assoc map_add_commute)
  apply (rule conjI)
   apply (metis disjoint_commute)
  apply (rule conjI, simp add: esllocked_def)
  done
*)

lemma essafe_EvtSeq :"\<lbrakk>resafe n re s h \<Gamma> Q; user_esys esys;
        \<forall>m s' h'. m \<le> n \<and> (s', h') \<Turnstile> Q  \<longrightarrow> essafe m esys s' h' \<Gamma> R\<rbrakk> 
      \<Longrightarrow>  essafe n (EvtSeq re esys) s h \<Gamma> R"
  apply (induct n arbitrary: re s h, simp, clarsimp)
  apply (rule conjI, clarsimp)
  using esaborts.simps apply auto[1]
  apply (clarsimp, erule esred.cases, simp_all)
   apply (metis prod.collapse)
  apply (drule_tac a = Map.empty and b = "hJ ++hF" and c = "fst re'" and d = "AnonyEvent Cskip" 
        and e = aa and f= ba in all6_impD)
   apply force
  apply (simp add: rellocked_def, clarsimp)
  apply (rule_tac x = h' and y = hJ' in ex2I, simp)
  by (smt (verit) bot_nat_0.extremum_unique essafe.simps(1) le_SucE le_boolD 
      lift_Suc_antimono_le linorder_linear not_less_eq_eq resafe.simps(2) snd_conv)


theorem rule_EvtSeq :"\<lbrakk>\<Gamma> \<turnstile>\<^sub>r\<^sub>e {P} re {Q};
                 \<Gamma> \<turnstile>\<^sub>e\<^sub>s {Q } esys {R}\<rbrakk> 
                \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>e\<^sub>s {P} (EvtSeq re esys) {R}"
  by (auto simp add: reCSL_def esCSL_def intro!: essafe_EvtSeq)

definition get_int_pre :: "state \<Rightarrow> revent set \<Rightarrow> (revent \<Rightarrow> assn) \<Rightarrow> bool"
  where "get_int_pre \<sigma> es Pre \<equiv> \<forall> re \<in> es.  \<sigma> \<Turnstile> (Pre re)" 

definition get_union_post :: "state \<Rightarrow> revent set \<Rightarrow> (revent \<Rightarrow> assn) \<Rightarrow> bool"
  where "get_union_post \<sigma> es Post \<equiv>  \<exists>re \<in> es. \<sigma> \<Turnstile> (Post re)" 

lemma pre_conj : "\<lbrakk> \<forall>re \<in> es. P \<sqsubseteq> (Pre re) ; \<sigma> \<Turnstile> P \<rbrakk> \<Longrightarrow> get_int_pre \<sigma> es Pre"
  using get_int_pre_def implies_def by blast

lemma post_dconj : "\<lbrakk>\<forall>re\<in>es. (Post re) \<sqsubseteq> Q; get_union_post \<sigma> es Post\<rbrakk> \<Longrightarrow> \<sigma> \<Turnstile> Q"
  using get_union_post_def implies_def by blast

lemma essafe_EvtSys : "\<lbrakk> \<forall> re \<in> es. user_revent re \<and> (\<forall>s h. (s, h) \<Turnstile> (Pre re) 
                        \<longrightarrow> resafe n re s h \<Gamma> (Post re)); 
                         \<forall> re \<in> es. (Post re) \<sqsubseteq> Q; get_int_pre (s, h) es Pre;
                         \<forall> re1 re2. re1 \<in> es \<and> re2 \<in> es \<longrightarrow> Post re1 \<sqsubseteq> Pre re2\<rbrakk>
                        \<Longrightarrow>  essafe n (EvtSys es) s h \<Gamma> Q"
  apply (induct n arbitrary: s h, simp, simp)
  apply (rule conjI, clarsimp)
   apply (erule esaborts.cases, simp_all)
   apply (drule_tac x = "re" in Set.bspec, simp) apply auto
   apply (drule_tac a = "aa" and b = "h" in all2_impD)
  using get_int_pre_def apply blast apply blast
  apply (erule esred.cases, simp_all)
  apply (frule_tac x = "re" in Set.bspec, simp) apply auto
  apply (drule_tac a = "s" and b = "h" in all2_impD)
   apply (simp add: get_int_pre_def)
  apply ( drule_tac a = "hJ" and b = "hF" and c = "ab" and d = "bb" and e = "a" and f = "b" in all6_impD)
   apply blast
  apply (drule imp2D, simp, simp, clarsimp)
  apply (rule_tac x = h' in exI, simp)
  apply (rule_tac Q = "Post (aa, ba)" in essafe_EvtSeq, simp, simp)
  apply (clarsimp, drule_tac a = "s'" and b = "h'a" in mall2_impD, clarsimp)
   apply (drule_tac x = "(ac, b)" in Set.bspec, simp) apply auto[1]
  apply (drule_tac a = "sa" and b = "ha" in all2_impD, simp)
   apply (rule_tac n = "Suc n" in resafe_mon, simp, simp)
  apply (drule mimpD)
  apply (metis pre_conj prod.collapse) 
  using essafe_mon by auto

theorem rule_EvtSys :  "\<lbrakk> \<forall> re \<in> es. \<Gamma> \<turnstile>\<^sub>r\<^sub>e {(Pre re)} re {Post re};
                         \<forall> re \<in> es. P \<sqsubseteq> Pre re;
                         \<forall> re \<in> es. (Post re) \<sqsubseteq> Q;
                         \<forall> re1 re2. re1 \<in> es \<and> re2 \<in> es \<longrightarrow> Post re1 \<sqsubseteq> Pre re2\<rbrakk>
                        \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>e\<^sub>s {P} (EvtSys es) {Q}"
  apply (simp add: esCSL_def reCSL_def, clarsimp)
  apply (rule essafe_EvtSys, simp_all)
  by (simp add: pre_conj)

definition all_Aemp :: "revent \<Rightarrow> assn"
  where "all_Aemp = (\<lambda>x. Aemp)"

corollary rule_EvtSys' :  " \<forall> re \<in> es. \<Gamma> \<turnstile>\<^sub>r\<^sub>e {Aemp} re {Aemp}
                        \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>e\<^sub>s {Aemp} (EvtSys es) {Aemp}"
  apply (rule_tac Pre = "all_Aemp" and Post = "all_Aemp" in rule_EvtSys, simp_all add: all_Aemp_def)
  by (simp_all add: implies_def)

lemma essafe_frame:
 "\<lbrakk> essafe n es s h J Q; 
    disjoint (dom h) (dom hR);
    disjoint (fvA R) (wrEsv es);
    (s,hR) \<Turnstile> R\<rbrakk>
  \<Longrightarrow> essafe n es s (h ++ hR) J (Q ** R)"
  apply (induct n arbitrary: es s h hR, simp, clarsimp)
  apply (rule conjI, clarify)
 (* no aborts *)
   apply (drule_tac a="hR ++ hF" in all_impD, simp, simp add: hsimps)
(* accesses *)
  apply (rule conjI, erule order_trans, simp)
(* step *)
  apply (clarify, frule esred_properties, clarsimp)
  apply (drule_tac a="hJ" and b="hR ++ hF" and c = es' and d = a and e = b in all5_impD)
   apply (metis map_add_assoc map_add_commute)
  apply (drule imp2D, simp)
  apply auto[1]
  apply (clarsimp, rule_tac y="hJ'" and x="h' ++ hR" in ex2I, clarsimp simp add: hsimps)
  apply (subst map_add_commute, simp add: hsimps)
  apply (drule mall4D, erule mimp4D, simp_all add: hsimps)
 apply (erule (1) disjoint_search)
  apply (subst assn_agrees, simp_all)
  using agrees_minusD agrees_search(1) disjoint_search(1) by blast

theorem esrule_frame:
 "\<lbrakk> \<Gamma> \<turnstile>\<^sub>e\<^sub>s {P} es {Q} ; disjoint (fvA R) (wrEsv es) \<rbrakk>
  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>e\<^sub>s {P ** R} es {Q ** R}"
  by (auto simp add: esCSL_def intro: essafe_frame)

subsection \<open>specification and proof rules for resource event systems\<close>

primrec 
  ressafe :: "nat \<Rightarrow> resys \<Rightarrow> stack \<Rightarrow> heap \<Rightarrow> (rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> bool"
where
  "ressafe 0 res s h \<Gamma> Q = True"
| "ressafe (Suc n) res s h \<Gamma> Q = (
 (\<forall>hF. disjoint (dom h) (dom hF) \<longrightarrow> \<not> resaborts res (s, h ++ hF))
\<and> (resaccesses res s \<subseteq> dom h)
\<and> (\<forall>hJ hF res' \<sigma>' x x' actk. 
      (res, (s, h ++ hJ ++ hF), x) -res-actk\<rightarrow> (res', \<sigma>', x')
    \<longrightarrow> (s, hJ) \<Turnstile> envs \<Gamma> (resllocked res') (resllocked res)
    \<longrightarrow> (disjoint (dom h) (dom hJ) \<and> disjoint (dom h) (dom hF) \<and> disjoint (dom hJ) (dom hF))
    \<longrightarrow> (\<exists>h' hJ'.
            snd \<sigma>' = h' ++ hJ' ++ hF
          \<and> disjoint (dom h') (dom hJ') \<and> disjoint (dom h') (dom hF) \<and> disjoint (dom hJ') (dom hF)
          \<and> (fst \<sigma>', hJ') \<Turnstile> envs \<Gamma> (resllocked res) (resllocked res')
          \<and> ressafe n res' (fst \<sigma>') h' \<Gamma> Q)))"

lemma ressafe_mon:
  "\<lbrakk> ressafe n res s h \<Gamma> Q; m \<le> n \<rbrakk> \<Longrightarrow> ressafe m res s h \<Gamma> Q"
  apply (induct m arbitrary: res s n h, simp)
  apply (case_tac n, clarify)
  apply (simp only: safe.simps, clarsimp)
  apply (drule_tac a = "hJ" and b = hF and c = aa and d = ba and e = ab and f = bb in all6_impD)
   apply blast
  apply (drule imp2D, simp, simp)
  apply (clarsimp, rule_tac x="h'" in exI, rule_tac x="hJ'" in exI, simp)
  done

lemma ressafe_agrees: 
    "\<lbrakk> ressafe n resys s h \<Gamma> Q ; 
     agrees (fvREsv resys \<union> fvA Q \<union> fvAs \<Gamma>) s s' \<rbrakk>
   \<Longrightarrow> ressafe n resys s' h \<Gamma> Q"
  apply (induct n arbitrary: resys s s' h, simp, simp only: ressafe.simps, clarify)
  apply (rule conjI, clarsimp)
   apply (drule_tac resaborts_agrees, simp, fast, simp, simp)
  apply (rule conjI, subst (asm) resaccesses_agrees, simp_all)
  apply (clarify, drule_tac X = "fvREsv (a,b) \<union> fvAs \<Gamma> \<union> fvA Q" in resred_agrees,
       simp (no_asm), fast, simp(no_asm), fast, clarify)
  apply (drule_tac a = "hJ" and b = hF and c = aa and d = ba and e = s'a and f = bb in all6_impD)
   apply auto[1]
  apply (drule imp2D)
  using assns_agrees apply blast
  apply blast
  apply (clarsimp, rule_tac x=h' and y=hJ' in ex2I, simp add: hsimps)
  apply (rule conjI, erule assns_agreesE, subst agreesC, assumption)
  apply (erule (1) mall5_imp2D, simp add: agreesC)
  apply (drule resred_properties, auto)
  done

definition 
  resCSL :: "(rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> resys \<Rightarrow> assn \<Rightarrow> bool" 
  ("_ \<turnstile>\<^sub>r\<^sub>e\<^sub>s { _ } _ { _ }")
  where
    "\<Gamma> \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P} resys {Q} \<equiv> (user_resys resys) \<and> (\<forall>n s h. (s, h) \<Turnstile> P \<longrightarrow> ressafe n resys s h \<Gamma> Q)"

lemma ressafe_conseq : "\<lbrakk> ressafe n res s h \<Gamma> Q; Q \<sqsubseteq> Q'\<rbrakk> \<Longrightarrow> ressafe n res s h \<Gamma> Q'"
  apply (induct n arbitrary: res s h, simp)
  apply (clarsimp, simp add : implies_def)
  apply (erule resred.cases, simp_all, clarify)
    apply (drule_tac a = "hJ" and b = "hF" and c = "a" and d = "EvtSeq (ad, bc) res" 
          and e = "ab" and f = "bb" in all6_impD)
     apply (meson resred.red_EvtSeq1)
    apply (drule imp2D, simp, simp)
    apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp)
   apply (drule_tac a = "hJ" and b = "hF" and c = "a" 
         and d = "ba"  and e = "ab" and f = "bb" in all6_impD)
  apply (meson resred.red_EvtSeq2)
   apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp, clarsimp)
  apply ( drule_tac a = "hJ" and b = "hF" and c = "a" and d = "EvtSeq (ad, bc) (EvtSys revts)" and  
          e = "ab" and f = "bb" in all6_impD)
   apply (meson resred.red_EvtSet)
  apply (simp add: resllocked_def, clarify, rule_tac x = "h'" in exI, simp)
  done

theorem rule_resconseq : "\<lbrakk>\<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P} res {Q};  P' \<sqsubseteq> P; Q \<sqsubseteq> Q' \<rbrakk> \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P'} res {Q'}"
  by (meson implies_def resCSL_def ressafe_conseq)

theorem rule_res_equiv : "\<lbrakk>\<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P} res {Q};  P' \<equiv>\<^sub>S\<^sub>L P; Q \<equiv>\<^sub>S\<^sub>L Q' \<rbrakk> \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P'} res {Q'}"
  using equiv_implies rule_resconseq by blast

lemma ressafe_res : 
"\<lbrakk>ressafe n (rs, es) s h (\<Gamma>(r := R)) Q; wf_resys (rs, es); r \<notin> set rs;
   disjoint (fvA R) (wrREsv (rs, es))\<rbrakk> \<Longrightarrow> 
   (\<forall>hR. r \<notin> reslocked (rs, es) \<longrightarrow> disjoint (dom h) (dom hR) 
     \<longrightarrow> (s,hR) \<Turnstile> R \<longrightarrow> ressafe n (r # rs, es) s (h ++ hR) \<Gamma> (Q ** R))
   \<and> (r \<in> reslocked (rs, es) \<longrightarrow> ressafe n (r # rs, es) s h \<Gamma> (Q ** R))"
  apply (induct n arbitrary: es s h, simp, clarsimp)
  apply (rule conjI, clarify)
   apply (rule conjI, simp add: resaborts_equiv, clarify)
    apply (metis disjoint_simps(4) dom_map_add map_add_assoc)
   apply (rule conjI, simp add: resaccesses_def, erule order_trans, simp)
   apply (clarify, frule resred_properties, clarsimp)
   apply (subgoal_tac "a = r # rs", simp)
    apply (case_tac "r \<in> set (resllocked (rs, b))", simp add: resllocked_def)
  apply (drule_tac a = "hJ ++ hR" and b = "hF" and c = rs and d = b and e = aa
          and f = "ba" in all6_impD, simp add: hsimps)
  using res_equiv3 apply blast
     apply (drule imp2D, subst sat_envs_expand [where r=r], simp_all add: resllocked_def)
       apply (simp add: reslocked_def eslocked_eq)
      apply (subgoal_tac "wf_resys (r # rs, es)")
       apply (subgoal_tac "wf_resys (a, b)")
        apply (simp add: wf_resys_def)
        apply (simp add: distinct_list_minus wf_esys_distinct_locked)
  using red_wf_resys apply blast
      apply (simp add: wf_resys_def)
      apply (intro exI conjI, simp, simp_all add: envs_upd hsimps rellocked_def)
  apply (metis envs_def list_minus_removeAll list_minus_removeAll2)
     apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp add: envs_removeAll_irr)
     apply (rule conjI, simp add: envs_def list_minus_removeAll)
     apply (drule (1) mall3_imp2D)
  using red_wf_resys res_equiv3 apply blast
     apply (simp add: reslocked_def eslocked_eq, drule mimpD)
      apply (meson disjoint_search(4) res_equiv3 resred_properties, simp)
    apply (drule_tac a="hJ" and b="hR ++ hF" and c = rs and d = b and e = aa
          and f = "ba" in all6_impD, simp add: hsimps)
  using res_equiv3 apply blast
    apply (drule imp2D)
      apply (simp add: envs_removeAll_irr envs_upd(1))
     apply auto[1]
    apply (clarsimp, rule_tac x = "h' ++ hR" and y = "hJ'" in ex2I, simp add: hsimps)
    apply (rule conjI, simp add: envs_upd(1) resllocked_def reslocked_eq)
     apply (drule (1) mall3_imp2D)
  using red_wf_resys res_equiv3 apply blast  
    apply (simp add: reslocked_def eslocked_eq, drule mimpD)
     apply (meson disjoint_search(1) disjoint_search(2) res_equiv3 resred_properties)
    apply (drule_tac a = "hR" in all_imp2D)
  using disjoint_commute apply blast
     apply (metis (no_types, lifting) agrees_minusD assn_agrees 
                disjoint_search(1) fst_conv res_equiv3 resred_properties)
    apply (simp add: map_add_commute)
  using resred.simps apply auto[1]
  apply (clarsimp, rule conjI, simp add: resaborts_equiv)
  apply (rule conjI, simp add: resaccesses_def)
  apply (clarify, frule resred_properties, clarsimp)
  apply (subgoal_tac "a = r # rs", simp)
    apply (drule_tac a="hJ" and b=" hF" and c = rs and d = b and e = aa
          and f = "ba" in all6_impD)
  using res_equiv3 apply blast
   apply (drule imp2D, simp add: envs_removeAll2 envs_upd(2) resllocked_def reslocked_eq, simp)
   apply (clarsimp, drule (1) mall3_imp2D)
  using red_wf_resys res_equiv3 apply blast
   apply (drule mimpD, meson disjoint_search(4) res_equiv3 resred_properties)
   apply (case_tac "r \<in> set (resllocked (rs, b))", simp add: resllocked_def)
    apply (intro exI conjI, simp+)
     apply (simp add: envs_removeAll2 envs_upd(2), simp add: reslocked_def eslocked_eq)
   apply (subst (asm) sat_envs_expand [where r=r]) back
      apply (simp_all add: resllocked_def reslocked_def eslocked_eq)
    apply (simp add: wf_resys_def)
  using distinct_list_minus wf_esys_distinct_locked apply blast
   apply (clarsimp, drule (2) all_imp2D, rule_tac x = "h' ++ h1" and y = " h2" in ex2I, 
        simp add: hsimps envs_upd)
  using resred.simps by auto

lemma ressafe_res_empty : "essafe n es s h \<Gamma> Q \<Longrightarrow> ressafe n ([], es) s h \<Gamma> Q"
  apply (induct n arbitrary: es s h, simp, clarsimp)
  apply (rule conjI, simp add: resaborts_equiv)
  apply (rule conjI, simp add: resaccesses_def, clarsimp)
  apply (subgoal_tac "a = []", simp)
   apply (drule_tac a = "hJ" and b = "hF" and c = "b" and d = "aa" and e = "ba" in all5_impD)
  apply (meson res_equiv2)
   apply (simp add: res_equiv2)
  apply (drule impD, simp add: resllocked_def)
   apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp add: resllocked_def)
  using resred.simps by auto

lemma ressafe_res_empty' : "ressafe n ([], es) s h \<Gamma> Q \<Longrightarrow> essafe n es s h \<Gamma> Q"
  apply (induct n arbitrary: es s h, simp, clarsimp)
  apply (rule conjI, simp add: resaborts_equiv)
  apply (rule conjI, simp add: resaccesses_def, clarsimp)
  apply (drule_tac a = "hJ" and b = "hF" and c = "[]" and d = "es'" and e = "a" and f = "b" in all6_impD)
  apply (metis res_equiv1)
  apply (drule impD, simp add: resllocked_def, clarsimp)
  apply (rule_tac x = "h'" and y = "hJ'" in ex2I, simp add: resllocked_def)
  done

lemma rule_res_empty : "\<Gamma> \<turnstile>\<^sub>e\<^sub>s { P } es { Q } \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>e\<^sub>s { P } ([], es) { Q}"
  by (simp add: esCSL_def resCSL_def user_resys_def ressafe_res_empty)

lemma rule_res1 : "\<lbrakk> \<Gamma>(r := R) \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P} (rs, es) {Q} ; disjoint (fvA R) (wrREsv (rs, es)); r \<notin> set rs \<rbrakk> 
  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>e\<^sub>s  {P ** R} (r # rs, es) {Q ** R}"
  apply (clarsimp simp add: resCSL_def)
  apply (rule conjI, simp add: user_resys_def, clarsimp)
  apply (drule_tac a = n and b = s and c = h1 in all3_impD, simp)
  by (simp add: ressafe_res user_resysD)

theorem rule_res : 
    "\<lbrakk>(update_list \<Gamma> \<G> rs) \<turnstile>\<^sub>e\<^sub>s {P} es {Q} ;disjoint (fvA (Aistar (map \<G> rs))) (wrEsv es)
    ; distinct rs\<rbrakk>  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P ** (Aistar (map \<G> rs))} (rs, es) {Q ** (Aistar (map \<G> rs))}"
  apply (induct rs arbitrary: \<Gamma>, simp, rule_tac P = P and Q = Q in rule_res_equiv)
  apply (simp add: rule_res_empty, simp add: assn_equiv_def, simp add: assn_equiv_def)
  apply (drule_tac a = "\<Gamma>(a := \<G> a)" in mall_impD, clarsimp)
  apply (rule_tac P = "(P ** Aistar (map \<G> rs)) ** \<G> a" and Q = "(Q ** Aistar (map \<G> rs)) ** \<G> a"
  in rule_res_equiv, rule rule_res1, simp, simp add: wrREsv_def, simp)
   apply (meson Aistar_equiv assn_equiv_symmetry) apply (meson Aistar_equiv assn_equiv_symmetry)
  done

theorem rule_rEvtSeq : "\<lbrakk>(update_list \<Gamma> \<G> rs) \<turnstile>\<^sub>r\<^sub>e {P} re {Q};
                         (update_list \<Gamma> \<G> rs) \<turnstile>\<^sub>e\<^sub>s {Q } esys {R};
                         disjoint (fvA (Aistar (map \<G> rs))) (wrEsv (EvtSeq re esys)); distinct rs\<rbrakk>
   \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P ** (Aistar (map \<G> rs))} (rs, (EvtSeq re esys)) {R ** (Aistar (map \<G> rs))}"
  by (rule rule_res, simp_all add: rule_EvtSeq)

theorem rule_rEvtSys :  "\<lbrakk>\<forall> re \<in> es. (update_list \<Gamma> \<G> rs) \<turnstile>\<^sub>r\<^sub>e {(Pre re)} re {Post re};
                         \<forall> re \<in> es. (Post re) \<sqsubseteq> Q; \<forall> re \<in> es. P \<sqsubseteq> (Pre re); 
                         \<forall> re1 re2. re1 \<in> es \<and> re2 \<in> es \<longrightarrow> Post re1 \<sqsubseteq> Pre re2;
                        disjoint (fvA (Aistar (map \<G> rs))) (wrEsv (EvtSys es)); distinct rs\<rbrakk>
                        \<Longrightarrow>  \<Gamma> \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P ** (Aistar (map \<G> rs))} (rs, (EvtSys es)) 
                                    {Q ** (Aistar (map \<G> rs))}"
  by (rule rule_res, simp_all add: rule_EvtSys)


lemma ressafe_frame:
 "\<lbrakk> ressafe n res s h J Q; 
    disjoint (dom h) (dom hR);
    disjoint (fvA R) (wrREsv res);
    (s,hR) \<Turnstile> R\<rbrakk>
  \<Longrightarrow> ressafe n res s (h ++ hR) J (Q ** R)"
  apply (induct n arbitrary: res s h hR, simp, clarsimp)
  apply (rule conjI, clarify)
 (* no aborts *)
   apply (drule_tac a="hR ++ hF" in all_impD, simp, simp add: hsimps)
(* accesses *)
  apply (rule conjI, erule order_trans, simp)
(* step *)
  apply (clarify, frule resred_properties, clarsimp)
  apply (drule_tac a="hJ" and b="hR ++ hF" and c = aa and d = ba and e = ab and f = bb in all6_impD)
  apply (metis map_add_assoc map_add_commute)
  apply (drule imp2D, simp)
  apply auto[1]
  apply (clarsimp, rule_tac y="hJ'" and x="h' ++ hR" in ex2I, clarsimp simp add: hsimps)
  apply (subst map_add_commute, simp add: hsimps)
  apply (drule mall5D, erule mimp4D, simp_all add: hsimps)
 apply (erule (1) disjoint_search)
  using agrees_minusD assn_agrees disjoint_search(1) by blast

theorem resrule_frame:
 "\<lbrakk> \<Gamma> \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P} res {Q} ; disjoint (fvA R) (wrREsv res) \<rbrakk>
  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P ** R} res {Q ** R}"
  by (auto simp add: resCSL_def intro: ressafe_frame)

subsection \<open>specification and proof rules for parallel event systems\<close>

primrec 
  pessafe :: "nat \<Rightarrow> paresys \<Rightarrow> stack \<Rightarrow> heap \<Rightarrow> (rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> bool"
  where
  "pessafe 0 pes s h \<Gamma> Q = True"
| "pessafe (Suc n) pes s h \<Gamma> Q =  (
 (\<forall>hF. disjoint (dom h) (dom hF) \<longrightarrow> \<not> pesaborts pes (s, h ++ hF))
\<and> (\<forall>hJ hF pes' \<sigma>' x x' actk. 
        (pes, (s, h ++ hJ ++ hF), x) -pes-actk\<rightarrow> (pes', \<sigma>', x')
    \<longrightarrow> (s, hJ) \<Turnstile> envs \<Gamma> (pesllocked pes') (pesllocked pes)
    \<longrightarrow> (disjoint (dom h) (dom hJ) \<and> disjoint (dom h) (dom hF) \<and> disjoint (dom hJ) (dom hF))
    \<longrightarrow> (\<exists>h' hJ'.
            snd \<sigma>' = h' ++ hJ' ++ hF
          \<and> disjoint (dom h') (dom hJ') \<and> disjoint (dom h') (dom hF) \<and> disjoint (dom hJ') (dom hF)
          \<and> (fst \<sigma>', hJ') \<Turnstile> envs \<Gamma> (pesllocked pes) (pesllocked pes')
          \<and> pessafe n pes' (fst \<sigma>') h' \<Gamma> Q)))"

definition 
  pesCSL :: "(rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> paresys \<Rightarrow> assn \<Rightarrow> bool" 
  ("_ \<turnstile>\<^sub>p\<^sub>e\<^sub>s { _ } _ { _ }")
  where
    "\<Gamma> \<turnstile>\<^sub>p\<^sub>e\<^sub>s {P} pes {Q} \<equiv> (user_pesys pes) \<and> (\<forall>n s h. (s, h) \<Turnstile> P \<longrightarrow> pessafe n pes s h \<Gamma> Q)"

lemma pessafe_conseq : "\<lbrakk> pessafe n pes s h \<Gamma> Q; Q \<sqsubseteq> Q'\<rbrakk> \<Longrightarrow> pessafe n pes s h \<Gamma> Q'"
    apply (induct n arbitrary: pes s h, simp)
  apply (clarsimp, simp add : implies_def)
  apply (erule pesred.cases, simp_all, clarsimp)
  apply (drule_tac a = "hJ" and b = "hF" and c = "pesa[k := (ab, bb)]" 
          and d = "a" and e = "b" in all5_impD)
  using pesred.red_Par apply blast
   apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp)
  done

theorem rule_pesconseq : "\<lbrakk> \<Gamma>  \<turnstile>\<^sub>p\<^sub>e\<^sub>s {P} pes {Q}; P' \<sqsubseteq> P; Q \<sqsubseteq> Q' \<rbrakk> \<Longrightarrow>  \<Gamma>  \<turnstile>\<^sub>p\<^sub>e\<^sub>s {P'} pes {Q'}"
  apply (simp add: pesCSL_def)
  using implies_def pessafe_conseq by blast

theorem rule_pes_equiv : "\<lbrakk> \<Gamma>  \<turnstile>\<^sub>p\<^sub>e\<^sub>s {P} pes {Q}; P' \<equiv>\<^sub>S\<^sub>L P; Q \<equiv>\<^sub>S\<^sub>L Q' \<rbrakk> \<Longrightarrow>  \<Gamma>  \<turnstile>\<^sub>p\<^sub>e\<^sub>s {P'} pes {Q'}"
  using equiv_implies rule_pesconseq by auto

lemma envs_app' : "disjoint (set a) (set b) \<Longrightarrow> disjoint (set a) (set c) \<Longrightarrow> disjoint (set b) (set c)
    \<Longrightarrow> envs \<Gamma> (a @ b @ c) (a @ b' @ c) = envs \<Gamma> b b'"
  by (simp add: envs_app(1) envs_app(2))

lemma disjoint_locked_list_update : 
        "\<lbrakk> \<forall>k'. k' < length l \<and> k' \<noteq> k \<longrightarrow> disjoint (reslocked re) (reslocked (l ! k'));
        disjoint_locked_list l ; k < length l \<rbrakk>
    \<Longrightarrow> disjoint_locked_list (l [k := re])"
  apply (simp add: disjoint_locked_list_equiv, clarify)
  apply (case_tac "k1 = k", simp)
  apply (case_tac "k2 = k")
   apply auto[1]
  by simp

lemma pesllocked_cancel : "\<lbrakk>disjoint_locked_list pes; pes ! k = res;
             pes' = pes[k := res']; k < length pes\<rbrakk>
        \<Longrightarrow> envs \<Gamma> (pesllocked pes) (pesllocked pes')
          = envs \<Gamma> (resllocked res) (resllocked res')"
  apply (simp add: peslocked_split)
  apply (rule envs_app')
    apply (metis disjoint_locked_with_property disjoint_search(1)
              disjoint_with_take peslocked_def reslocked_eq)
   apply (simp add: peslocked_eq disjoint_between_take_drop disjoint_locked_between_property)
  by (metis disjoint_locked_with_property disjoint_with_drop peslocked_def reslocked_eq)

lemma pessafe_pesllocked_cancel :
        "\<lbrakk> disjoint_locked_list pes; pes' = pes[k := res']; pes ! k = res; k < length pes;
         \<forall>k'. k' < length pes \<and> k \<noteq> k' \<longrightarrow> disjoint (reslocked res') (reslocked (pes ! k'))\<rbrakk>
        \<Longrightarrow> envs \<Gamma> (pesllocked pes') (pesllocked pes)
          = envs \<Gamma> (resllocked res') (resllocked res)"
  apply (rule pesllocked_cancel, simp_all)
  using disjoint_locked_list_update apply blast
  by auto

lemma pessafe: 
" \<lbrakk>\<forall>k. k < length pes \<longrightarrow> ressafe n (pes ! k) s (hs ! k) \<Gamma> (Qs ! k);
   disjoint_heap_list hs; disjoint_locked_list pes;
   \<forall>k1 k2. k1 < length pes \<and> k2 < length pes \<and> k1 \<noteq> k2 
          \<longrightarrow> disjoint (fvREsv (pes ! k1) \<union> fvA (Qs ! k1) \<union> fvAs \<Gamma>) (wrREsv (pes ! k2));
    length pes = length hs\<rbrakk>
   \<Longrightarrow> pessafe n pes s (hplus_list hs) \<Gamma> (Aistar Qs)"
  apply (induct n arbitrary: pes s hs, simp, clarsimp)
  apply (rule conjI, clarsimp, erule pesaborts.cases, clarsimp)
    apply (simp add: pessafe_noaborts, clarsimp)
  apply (meson disjoint_list_equiv disjoint_search(2) disjoint_search(4) reswrites_accesses)
  apply (clarsimp, erule pesred.cases, simp)
  apply (frule_tac a = "k" in allD, clarsimp)
  apply (drule_tac a = "hJ" and b = "(hplus_list (hs[ k:= Map.empty]) ++ hF)"
          and c = "ab" and d = "bb" and e = "a" and f = "b" in all6_impD)
  using pessafe_hsimps2 apply auto[1]
  apply (drule imp2D)
    apply (simp add: pessafe_pesllocked_cancel)
   apply (rule conjI, simp add: disjoint_hplus_list1)
   apply (rule conjI, simp add: disjoint_hplus_list3 disjoint_hplus_list1 )
    apply (simp add: disjoint_hplus_list3)
   apply (metis (no_types, lifting) disjoint_search(1) 
          disjoint_simps(4) dom_map_add hplus_list_exchange)
  apply (clarsimp, rule_tac x = "h' ++ (hplus_list (hs[k := Map.empty]))" and y = "hJ'" in ex2I, simp)
  apply (rule conjI)
   apply (metis map_add_assoc map_add_commute)
  apply (rule conjI) apply auto[1]
  apply (rule conjI)
   apply (simp add: disjoint_hplus_list2)
  apply (rule conjI)
  apply (simp add: pesllocked_cancel)
   apply (drule resred_properties)
   apply (clarsimp, drule_tac a = "pesa[k := (ab, bb)]" and b = "a"
                              and c = "hs[k := h']" in mall3_impD)
   apply (clarsimp, case_tac "ka = k", simp, simp)
   apply (rule_tac s = "s" in ressafe_agrees)
    apply (rule_tac n = "Suc n" in ressafe_mon, simp, simp)
   apply (drule_tac a = "ka" and b = "k" in all2_impD, simp, simp)
   apply auto[1]
  apply (drule mimp4D)
  using disjoint_heap_update1 apply presburger
  using disjoint_locked_list_update apply force
    apply (clarsimp, drule_tac a = "k1" and b = "k2" in all2_impD, simp)
    apply (case_tac "k1 \<noteq> k") apply (case_tac "k2 \<noteq> k", simp)
     apply auto[1] apply auto[1]
   apply simp
  apply (subgoal_tac "h' ++ hplus_list (hs[k := Map.empty]) = hplus_list (hs[k := h'])", simp)
  by (metis disjoint_heap_update1 hplus_list_exchange 
        length_list_update list_update_overwrite nth_list_update_eq)

lemma split_Aistar : "(s, h) \<Turnstile> Aistar Ps \<Longrightarrow> (\<exists>hs. length hs = length Ps  \<and> disjoint_heap_list hs 
                          \<and> (\<forall>k < length Ps. (s, hs ! k) \<Turnstile> Ps ! k ) \<and> hplus_list hs = h)" 
  apply (induct Ps arbitrary: s h, simp, clarsimp)
  apply (drule mall2_impD, simp, clarsimp)
  apply (rule_tac x = "h1 # hs" in exI, simp)
  apply (rule conjI) 
  using disjoint_heap_with_equiv2 disjoint_hplus_list1 disjoint_search(1) apply blast
  using less_Suc_eq_0_disj by auto

theorem rule_pes : " \<lbrakk>\<forall>k. k < length pes \<longrightarrow> \<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s  {Ps ! k} (pes ! k) {Qs ! k};
                  \<forall>k1 k2. k1 < length pes \<and> k2 < length pes \<and> k1 \<noteq> k2 
                  \<longrightarrow> disjoint (fvREsv (pes ! k1) \<union> fvA (Qs ! k1) \<union> fvAs \<Gamma>) (wrREsv (pes ! k2));
                  length pes = length Ps \<rbrakk> 
                  \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>p\<^sub>e\<^sub>s {Aistar Ps} pes {Aistar Qs}"
  apply (simp add: resCSL_def pesCSL_def, clarify)
  apply (drule split_Aistar, clarify)
  apply (rule pessafe, simp_all)
  apply (simp add: user_pesysD wf_peslocked)
  by blast

lemma List_Aemp_equiv : "Aistar (replicate n Aemp) \<equiv>\<^sub>S\<^sub>L Aemp"
  by (induct n, simp_all add: assn_equiv_def)

theorem rule_pes' : " \<lbrakk>\<forall>k. k < length pes \<longrightarrow> \<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s  {Aemp} (pes ! k) {Aemp};
                  \<forall>k1 k2. k1 < length pes \<and> k2 < length pes \<and> k1 \<noteq> k2 
                  \<longrightarrow> disjoint (fvREsv (pes ! k1)  \<union> fvAs \<Gamma>) (wrREsv (pes ! k2))\<rbrakk> 
                  \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>p\<^sub>e\<^sub>s {Aemp} pes {Aemp}"
  apply (rule_tac P = "Aistar (replicate (length pes) Aemp)" and Q = "Aistar (replicate (length pes)
   Aemp)" in rule_pes_equiv, rule rule_pes, simp_all) apply blast
  by (simp_all add: assn_equiv_symmetry List_Aemp_equiv)


corollary rule_pes2' : "\<lbrakk>\<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P1} res1 {Q1} ; \<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P2} res2 {Q2};
           disjoint ((fvREsv res1) \<union> fvA Q1 \<union> fvAs \<Gamma>) (wrREsv res2);
           disjoint ((fvREsv res2) \<union> fvA Q2 \<union> fvAs \<Gamma>) (wrREsv res1)\<rbrakk>
           \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>p\<^sub>e\<^sub>s {Aistar [P1, P2]} [res1, res2] {Aistar [Q1, Q2]}"
  apply (rule rule_pes, simp_all add: less_Suc_eq)
  by auto

corollary rule_pes2 : "\<lbrakk>\<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P1} res1 {Q1} ; \<Gamma>  \<turnstile>\<^sub>r\<^sub>e\<^sub>s {P2} res2 {Q2};
           disjoint ((fvREsv res1) \<union> fvA Q1 \<union> fvAs \<Gamma>) (wrREsv res2);
           disjoint ((fvREsv res2) \<union> fvA Q2 \<union> fvAs \<Gamma>) (wrREsv res1)\<rbrakk>
           \<Longrightarrow> \<Gamma>  \<turnstile>\<^sub>p\<^sub>e\<^sub>s {P1 ** P2} [res1, res2] {Q1 ** Q2}"
  apply (rule_tac P = "Aistar [P1, P2]" and Q = "Aistar [Q1, Q2]" in rule_pesconseq)
  using rule_pes2' apply auto[1]
  by (simp_all add: implies_def)

lemma pessafe_frame:
 "\<lbrakk> pessafe n pes s h J Q; 
    disjoint (dom h) (dom hR);
    disjoint (fvA R) (wrPEsv pes);
    (s,hR) \<Turnstile> R\<rbrakk>
  \<Longrightarrow> pessafe n pes s (h ++ hR) J (Q ** R)"
  apply (induct n arbitrary: pes s h hR, simp, clarsimp)
  apply (rule conjI, clarify)
 (* no aborts *)
   apply (drule_tac a="hR ++ hF" in all_impD, simp, simp add: hsimps)
(* step *)
  apply (clarify, frule pesred_properties, clarsimp)
  apply (drule_tac a = hJ and b = "hR ++ hF" and c = pes' and d = a and e = b in all5_impD)
  apply (metis map_add_assoc map_add_commute)
  apply (drule imp2D, simp)
  apply force
  apply (clarsimp, rule_tac y="hJ'" and x="h' ++ hR" in ex2I, clarsimp simp add: hsimps)
  apply (subst map_add_commute, simp add: hsimps)
  apply (drule mall4D, erule mimp4D, simp_all add: hsimps)
   apply (erule (1) disjoint_search)
  apply (subst assn_agrees, simp_all, fastforce)
  done

theorem pesrule_frame:
 "\<lbrakk> \<Gamma> \<turnstile>\<^sub>p\<^sub>e\<^sub>s {P} pes {Q} ; disjoint (fvA R) (wrPEsv pes) \<rbrakk>
  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>p\<^sub>e\<^sub>s {P ** R} pes {Q ** R}"
  by (auto simp add: pesCSL_def intro: pessafe_frame)

subsection \<open>specification and proof rules for parallel resource event systems\<close>

primrec 
  rpessafe :: "nat \<Rightarrow> rparesys \<Rightarrow> stack \<Rightarrow> heap \<Rightarrow> (rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> bool"
  where
  "rpessafe 0 rpes s h \<Gamma> Q = True"
| "rpessafe (Suc n) rpes s h \<Gamma> Q =  (
 (\<forall>hF. disjoint (dom h) (dom hF) \<longrightarrow> \<not> rpesaborts rpes (s, h ++ hF))
\<and> (\<forall>hJ hF rpes' \<sigma>' x x' actk. 
        (rpes, (s, h ++ hJ ++ hF), x) -rpes-actk\<rightarrow> (rpes', \<sigma>', x')
    \<longrightarrow> (s, hJ) \<Turnstile> envs \<Gamma> (rpesllocked rpes') (rpesllocked rpes)
    \<longrightarrow> (disjoint (dom h) (dom hJ) \<and> disjoint (dom h) (dom hF) \<and> disjoint (dom hJ) (dom hF))
    \<longrightarrow> (\<exists>h' hJ'.
            snd \<sigma>' = h' ++ hJ' ++ hF
          \<and> disjoint (dom h') (dom hJ') \<and> disjoint (dom h') (dom hF) \<and> disjoint (dom hJ') (dom hF)
          \<and> (fst \<sigma>', hJ') \<Turnstile> envs \<Gamma> (rpesllocked rpes) (rpesllocked rpes')
          \<and> rpessafe n rpes' (fst \<sigma>') h' \<Gamma> Q)))"

definition 
  rpesCSL :: "(rname \<Rightarrow> assn) \<Rightarrow> assn \<Rightarrow> rparesys \<Rightarrow> assn \<Rightarrow> bool" 
  ("_ \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s { _ } _ { _ }")
  where
    "\<Gamma> \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {P} rpes {Q} \<equiv> (user_rpesys rpes) \<and> (\<forall>n s h. (s, h) \<Turnstile> P \<longrightarrow> rpessafe n rpes s h \<Gamma> Q)"

lemma rpessafe_conseq : "\<lbrakk> rpessafe n (rs, pes) s h \<Gamma> Q; Q \<sqsubseteq> Q'\<rbrakk> \<Longrightarrow> rpessafe n (rs, pes) s h \<Gamma> Q'"
    apply (induct n arbitrary: pes s h, simp)
  apply (clarsimp, simp add : implies_def)
  apply (erule rpesred.cases, simp_all, clarsimp)
  apply (drule  all6_impD)
  using rpesred.red_Par apply blast
   apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp)
  done

theorem rule_rpesconseq : "\<lbrakk>\<Gamma>  \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {P} rpes {Q};  P' \<sqsubseteq> P; Q \<sqsubseteq> Q' \<rbrakk> \<Longrightarrow>  \<Gamma>  \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {P'} rpes {Q'}"
  apply (simp add: rpesCSL_def)
  by (metis implies_def rpessafe_conseq surj_pair)

theorem rule_rpes_equiv : "\<lbrakk>\<Gamma>  \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {P} rpes {Q};  P' \<equiv>\<^sub>S\<^sub>L P; Q \<equiv>\<^sub>S\<^sub>L Q' \<rbrakk> \<Longrightarrow>  \<Gamma>  \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {P'} rpes {Q'}"
  using equiv_implies rule_rpesconseq by blast

lemma rpessafe_res:
 "\<lbrakk> rpessafe n (rs, pes) s h (\<Gamma>(r := R)) Q;  wf_rpesys (rs,pes); r \<notin> set rs;
   disjoint (fvA R) (wrPEsv pes) \<rbrakk> \<Longrightarrow> (\<forall>hR. r \<notin> rpeslocked (rs, pes) \<longrightarrow> disjoint (dom h) (dom hR) 
     \<longrightarrow> (s,hR) \<Turnstile> R \<longrightarrow> rpessafe n (r # rs, pes) s (h ++ hR) \<Gamma> (Q ** R))
   \<and> (r \<in> rpeslocked (rs, pes) \<longrightarrow> rpessafe n (r # rs, pes) s h \<Gamma> (Q ** R))"
  apply (induct n arbitrary: pes s h, simp, simp add: wf_rpesys_def)
  apply (rule conjI, clarify)
  apply (rule conjI, clarify) 
  apply (metis disjoint_simps(4) dom_map_add map_add_assoc rpesaborts_equiv)
   apply (clarify, frule rpesred_properties, clarsimp)
   apply (subgoal_tac "a = r # rs", simp)
    apply (case_tac "r \<in> set (rpesllocked (rs, b))", simp add: rpesllocked_def)
  apply (drule_tac a = "hJ ++ hR" and b = "hF" and c = rs and d = b and e = aa
          and f = "ba" in all6_impD, simp add: hsimps)
  using rpes_equiv3 apply blast
     apply (drule imp2D, subst sat_envs_expand [where r=r], simp_all add: rpesllocked_def)
       apply (simp add: rpeslocked_def peslocked_eq)
      apply (subgoal_tac "wf_rpesys (r # rs, pes)")
       apply (subgoal_tac "wf_rpesys (a, b)")
        apply (simp add: wf_rpesys_def)
        apply (simp add: distinct_list_minus wf_pesys_distinct_locked)
  using red_wf_rpesys apply blast
      apply (simp add: wf_rpesys_def)
      apply (intro exI conjI, simp, simp_all add: envs_upd hsimps rellocked_def)
  apply (metis envs_def list_minus_removeAll list_minus_removeAll2)
     apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp add: envs_removeAll_irr)
     apply (rule conjI, simp add: envs_def list_minus_removeAll)
     apply (drule (1) mall3_imp2D)
  using red_wf_pesys rpes_equiv2 apply blast
     apply (simp add: rpeslocked_def peslocked_eq, drule mimpD)
      apply (meson disjoint_search(4) rpes_equiv3 rpesred_properties, simp)
    apply (drule_tac a="hJ" and b="hR ++ hF" and c = rs and d = b and e = aa
          and f = "ba" in all6_impD, simp add: hsimps)
  using rpes_equiv3 apply blast
    apply (drule imp2D)
      apply (simp add: envs_removeAll_irr envs_upd(1))
     apply auto[1]
    apply (clarsimp, rule_tac x = "h' ++ hR" and y = "hJ'" in ex2I, simp add: hsimps)
    apply (rule conjI, metis envs_upd(1) fst_eqD removeAll_id rpesllocked_def rpeslocked_eq sndI)
  apply (drule (1) mall3_imp2D)
  using red_wf_pesys rpes_equiv2 apply blast
    apply (simp add: rpeslocked_def peslocked_eq, drule mimpD)
  using disjoint_search(4) apply blast
    apply (drule_tac a = "hR" in all_imp2D)
  using disjoint_commute apply blast
  using agrees_minusD assn_agrees disjoint_search(1) apply blast
    apply (simp add: map_add_commute)
  using rpesred.simps apply auto[1]
apply (clarsimp, rule conjI, simp add: rpesaborts_equiv)
  apply (clarify, frule rpesred_properties, clarsimp)
  apply (subgoal_tac "a = r # rs", simp)
    apply (drule_tac a="hJ" and b=" hF" and c = rs and d = b and e = aa
          and f = "ba" in all6_impD)
  using rpes_equiv3 apply blast
   apply (drule imp2D)
  apply (metis envs_removeAll2 envs_upd(2) fst_eqD rpesllocked_def rpeslocked_eq sndI, simp)
   apply (clarsimp, drule (1) mall3_imp2D)
  using red_wf_pesys rpes_equiv2 apply blast
   apply (drule mimpD, meson disjoint_search(4) rpes_equiv3 resred_properties)
   apply (case_tac "r \<in> set (rpesllocked (rs, b))", simp add: rpesllocked_def)
    apply (intro exI conjI, simp+)
     apply (simp add: envs_removeAll2 envs_upd(2), simp add: rpeslocked_def peslocked_eq)
   apply (subst (asm) sat_envs_expand [where r=r]) back
      apply (simp_all add: rpeslocked_def peslocked_eq rpesllocked_def)
  using distinct_list_minus wf_pesys_distinct_locked apply blast
   apply (clarsimp, drule (2) all_imp2D, rule_tac x = "h' ++ h1" and y = " h2" in ex2I, 
        simp add: hsimps envs_upd)
  by (metis fst_conv rpes_invres)

lemma rpessafe_res_empty : "pessafe n pes s h \<Gamma> Q \<Longrightarrow> rpessafe n ([], pes) s h \<Gamma> Q"
  apply (induct n arbitrary: pes s h, simp, clarsimp)
  apply (rule conjI, simp add: rpesaborts_equiv, clarsimp)
  apply (subgoal_tac "a = []", simp)
   apply (drule_tac a = "hJ" and b = "hF" and c = "b" and d = "aa" and e = "ba" in all5_impD)
    apply (metis rpes_equiv2)
   apply (drule imp2D, simp add: rpesllocked_def) apply blast
   apply (clarsimp, rule_tac x = "h'" and y = "hJ'" in ex2I, simp add: rpesllocked_def)
  by (metis fst_conv rpes_invres)

lemma rule_rpes_empty : "\<Gamma> \<turnstile>\<^sub>p\<^sub>e\<^sub>s { P } pes { Q } \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s { P } ([], pes) { Q }"
  by (simp add: pesCSL_def rpesCSL_def user_rpesys_def rpessafe_res_empty)

lemma rule_rpes1 : "\<lbrakk> \<Gamma>(r := R) \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {P} (rs, pes) {Q} ; 
        disjoint (fvA R) (wrRPEsv (rs, pes)); r \<notin> set rs \<rbrakk> 
  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s  {P ** R} (r # rs, pes) {Q ** R}"
  apply (clarsimp simp add: rpesCSL_def)
  apply (rule conjI, simp add: user_rpesys_def, clarsimp)
  apply (drule_tac a = n and b = s and c = h1 in all3_impD, simp)
  by (simp add: rpessafe_res user_rpesysD)

theorem rule_rpes : 
    "\<lbrakk>(update_list_env \<Gamma> upd) \<turnstile>\<^sub>p\<^sub>e\<^sub>s {P} pes {Q} ;disjoint (fvA (Aistar (map snd upd))) (wrPEsv pes)
    ; distinct (map fst upd)\<rbrakk>  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {P ** (Aistar (map snd upd))} ((map fst upd), pes) {Q ** (Aistar (map snd upd))}"
  apply (induct upd arbitrary: \<Gamma>, simp, rule_tac P = P and Q = Q in rule_rpes_equiv)
     apply (simp add: rule_rpes_empty, simp add: assn_equiv_def, simp add: assn_equiv_def)
  apply (rule_tac P = "P ** Aistar (map snd upd) ** (snd a)" and Q = "Q ** Aistar (map snd upd) ** 
  (snd a)" in rule_rpes_equiv)
    apply (drule_tac a = "\<Gamma>(fst a := snd a)" in mallD, simp)
    apply (rule rule_rpes1, simp_all)
  using Astar_assoc_equiv Astar_assoc_equiv2 assn_equiv_symmetry assn_equiv_trans apply blast
  using Astar_assoc_equiv Astar_assoc_equiv2 assn_equiv_trans by blast

corollary rule_rpes' : "\<lbrakk>(update_list_env \<Gamma> upd) \<turnstile>\<^sub>p\<^sub>e\<^sub>s {Aemp} pes {Aemp} ;disjoint (fvA (Aistar (map snd upd))) (wrPEsv pes)
    ; distinct rs; I \<equiv>\<^sub>S\<^sub>L Aistar (map snd upd); map fst upd = rs\<rbrakk>  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {I} (rs, pes) {I}"
  apply (drule rule_rpes, simp_all, rule_tac P = "Aemp ** Aistar (map snd upd)" and Q = "Aemp ** 
  Aistar (map snd upd)" in rule_rpes_equiv)
  by (simp_all add: assn_equiv_def)

lemma rpessafe_frame:
 "\<lbrakk> rpessafe n rpes s h J Q; 
    disjoint (dom h) (dom hR);
    disjoint (fvA R) (wrRPEsv rpes);
    (s,hR) \<Turnstile> R\<rbrakk>
  \<Longrightarrow> rpessafe n rpes s (h ++ hR) J (Q ** R)"
  apply (induct n arbitrary: rpes s h hR, simp, clarsimp)
  apply (rule conjI, clarify)
 (* no aborts *)
   apply (drule_tac a="hR ++ hF" in all_impD, simp, simp add: hsimps)
(* step *)
  apply (clarify, frule rpesred_properties, clarsimp)
  apply (drule_tac a = hJ and b = "hR ++ hF" and c = aa and d = ba and e = ab and f= bb in all6_impD)
   apply (metis map_add_assoc map_add_commute)
  apply (drule imp2D, simp)
   apply force
  apply (clarsimp, rule_tac y="hJ'" and x="h' ++ hR" in ex2I, clarsimp simp add: hsimps)
  apply (subst map_add_commute, simp add: hsimps)
  apply (drule mall5D, erule mimp4D, simp_all add: hsimps)
  using disjoint_search(4) apply blast
  apply (subst assn_agrees, simp_all, fastforce)
  done

theorem rpesrule_frame:
 "\<lbrakk> \<Gamma> \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {P} rpes {Q} ; disjoint (fvA R) (wrRPEsv rpes) \<rbrakk>
  \<Longrightarrow> \<Gamma> \<turnstile>\<^sub>r\<^sub>p\<^sub>e\<^sub>s {P ** R} rpes {Q ** R}"
  by (auto simp add: rpesCSL_def intro: rpessafe_frame)

end


