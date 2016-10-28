Require Import Coq.Strings.String.

Require Import compcert.lib.Integers.
Require Import compcert.common.AST.
Require Import compcert.cfrontend.Clight.
Require Import compcert.common.Globalenvs.
Require Import compcert.common.Memory.
Require Import compcert.common.Memdata.
Require Import compcert.common.Values.

Require Import msl.Coqlib2.
Require Import msl.eq_dec.
Require Import msl.seplog.
Require Import veric.initial_world.
Require Import veric.juicy_mem.
Require Import veric.juicy_mem_lemmas.
Require Import veric.semax_prog.
Require Import veric.compcert_rmaps.
Require Import veric.Clight_new.
Require Import veric.Clightnew_coop.
Require Import veric.semax.
Require Import veric.semax_ext.
Require Import veric.juicy_extspec.
Require Import veric.initial_world.
Require Import veric.juicy_extspec.
Require Import veric.juicy_safety.
Require Import veric.tycontext.
Require Import veric.semax_ext.
Require Import veric.res_predicates.
Require Import veric.mem_lessdef.
Require Import floyd.coqlib3.
Require Import sepcomp.semantics.
Require Import sepcomp.step_lemmas.
Require Import sepcomp.event_semantics.
Require Import concurrency.coqlib5.
Require Import concurrency.semax_conc_pred.
Require Import concurrency.semax_conc.
Require Import concurrency.juicy_machine.
Require Import concurrency.concurrent_machine.
Require Import concurrency.scheduler.
Require Import concurrency.addressFiniteMap.
Require Import concurrency.permissions.
Require Import concurrency.JuicyMachineModule.
Require Import concurrency.age_to.
Require Import concurrency.sync_preds_defs.
Require Import concurrency.sync_preds.
Require Import concurrency.join_lemmas.
Require Import concurrency.aging_lemmas.
Require Import concurrency.lksize.
Require Import concurrency.cl_step_lemmas.
Require Import concurrency.resource_decay_lemmas.
Require Import concurrency.resource_decay_join.
Require Import concurrency.semax_invariant.
(* Require Import concurrency.sync_preds. *)

Set Bullet Behavior "Strict Subproofs".

(** Lemmas common to both parts of the progress/preservation simulation results *)

Lemma lock_coherence_align lset Phi m b ofs :
  lock_coherence lset Phi m ->
  AMap.find (elt:=option rmap) (b, ofs) lset <> None ->
  (align_chunk Mint32 | ofs).
Proof.
  intros lock_coh find.
  specialize (lock_coh (b, ofs)).
  destruct (AMap.find (elt:=option rmap) (b, ofs) lset) as [[o|]|].
  + destruct lock_coh as [L _]; revert L; clear.
    unfold load_at; simpl.
    Transparent Mem.load.
    unfold Mem.load.
    if_tac. destruct H; auto. discriminate.
  + destruct lock_coh as [L _]; revert L; clear.
    unfold load_at; simpl.
    unfold Mem.load.
    if_tac. destruct H; auto. discriminate.
  + tauto.
Qed.

Lemma lset_valid_access m m_any tp Phi b ofs
  (compat : mem_compatible_with tp m Phi) :
  lock_coherence (lset tp) Phi m_any ->
  AMap.find (elt:=option rmap) (b, ofs) (lset tp) <> None ->
  Mem.valid_access (restrPermMap (mem_compatible_locks_ltwritable (mem_compatible_forget compat))) Mint32 b ofs Writable.
Proof.
  intros C F.
  split.
  - intros ofs' r. eapply lset_range_perm; eauto.
  - eapply lock_coherence_align; eauto.
Qed.

Lemma mem_compatible_with_age {n tp m phi} :
  mem_compatible_with tp m phi ->
  mem_compatible_with (age_tp_to n tp) m (age_to n phi).
Proof.
  intros [J AC LW LJ JL]; constructor.
  - rewrite join_all_joinlist in *.
    rewrite maps_age_to.
    apply joinlist_age_to, J.
  - apply mem_cohere_age_to; easy.
  - apply lockSet_Writable_age; easy.
  - apply juicyLocks_in_lockSet_age. easy.
  - apply lockSet_in_juicyLocks_age. easy.
Qed.

Lemma matchfunspec_age_to e Gamma n Phi :
  matchfunspec e Gamma Phi ->
  matchfunspec e Gamma (age_to n Phi).
Proof.
  unfold matchfunspec in *.
  apply age_to_pred.
Qed.

Lemma restrPermMap_mem_contents p' m (Hlt: permMapLt p' (getMaxPerm m)): 
  Mem.mem_contents (restrPermMap Hlt) = Mem.mem_contents m.
Proof.
  reflexivity.
Qed.

Lemma islock_valid_access tp m b ofs p
      (compat : mem_compatible tp m) :
  (4 | ofs) ->
  lockRes tp (b, ofs) <> None ->
  p <> Freeable ->
  Mem.valid_access
    (restrPermMap
       (mem_compatible_locks_ltwritable compat))
    Mint32 b ofs p.
Proof.
  intros div islock NE.
  eapply Mem.valid_access_implies with (p1 := Writable).
  2:destruct p; constructor || tauto.
  pose proof lset_range_perm.
  do 6 autospec H.
  split; auto.
  (* (* necessary if we change LKSIZE to something bigger than 4: *)
  intros loc range.
  apply H.
  unfold size_chunk in *.
  unfold LKSIZE in *.
  omega. *)
Qed.

Lemma LockRes_age_content1 js n a :
  lockRes (age_tp_to n js) a = option_map (option_map (age_to n)) (lockRes js a).
Proof.
  cleanup.
  rewrite lset_age_tp_to, AMap_find_map_option_map.
  reflexivity.
Qed.

Lemma join_sub_to_joining {A} {J : Join A}
      {_ : Perm_alg A} {_ : Sep_alg A} {_ : Canc_alg A} {_ : Disj_alg A}
  (a b e : A) :
    join_sub e a ->
    join_sub e b ->
    joins a b ->
    identity e.
Proof.
  intros la lb ab.
  eapply join_sub_joins_identity with b; auto.
  apply (@join_sub_joins_trans _ _ _ _ _ a); auto.
Qed.

Lemma join_sub_join {A} {J : Join A}
      {PA : Perm_alg A} {SA : Sep_alg A} {_ : Canc_alg A} {DA : Disj_alg A} {CA : Cross_alg A} 
      (a b c x : A) :
  join a b c ->
  join_sub a x ->
  join_sub b x ->
  join_sub c x.
Proof.
  intros j (d, ja) (e, jb).
  destruct (@cross_split _ _ _ _ _ _ _ _ ja jb)
    as ((((ab, ae), bd), de) & ha & hd & hb & he).
  exists de.
  assert (Iab : identity ab)
    by (apply join_sub_to_joining with a b; eexists; eauto).
  pose proof join_unit1_e ae a Iab ha. subst ae. clear ha.
  pose proof join_unit1_e bd b Iab hb. subst bd. clear hb.
  apply join_comm in ja.
  apply join_comm in hd.
  destruct (join_assoc hd ja) as (c' & abc' & dec'x).
  apply join_comm in abc'.
  assert (c = c'). eapply join_eq. apply j. apply abc'. subst c'.
  apply join_comm; auto.
Qed.

Lemma Ejuicy_sem : juicy_sem = juicy_core_sem cl_core_sem.
Proof.
  unfold juicy_sem; simpl.
  f_equal.
  unfold SEM.Sem, SEM.CLN_evsem.
  rewrite SEM.CLN_msem.
  reflexivity.
Qed.
  
Lemma level_jm_ m tp Phi (compat : mem_compatible_with tp m Phi)
      i (cnti : containsThread tp i) :
  level (jm_ cnti compat) = level Phi.
Proof.
  rewrite level_juice_level_phi.
  apply join_sub_level.
  unfold jm_ in *.
  unfold personal_mem in *.
  simpl.
  apply compatible_threadRes_sub, compat.
Qed.

Definition pures_same phi1 phi2 := forall loc k pp, phi1 @ loc = PURE k pp <-> phi2 @ loc = PURE k pp.

Lemma pures_same_sym phi1 phi2 : pures_same phi1 phi2 -> pures_same phi2 phi1.
Proof.
  unfold pures_same in *.
  intros H loc k pp; rewrite (H loc k pp); intuition.
Qed.

Lemma joins_pures_same phi1 phi2 : joins phi1 phi2 -> pures_same phi1 phi2.
Proof.
  intros (phi3, J) loc k pp; apply resource_at_join with (loc := loc) in J.
  split; intros E; rewrite E in J; inv J; auto.
Qed.

Lemma join_sub_pures_same phi1 phi2 : join_sub phi1 phi2 -> pures_same phi1 phi2.
Proof.
  intros (phi3, J) loc k pp; apply resource_at_join with (loc := loc) in J.
  split; intros E; rewrite E in J; inv J; auto.
Qed.

Lemma pures_same_eq_l phi1 phi1' phi2 :
  pures_same phi1 phi1' -> 
  pures_eq phi1 phi2 -> 
  pures_eq phi1' phi2.
Proof.
  intros E [M N]; split; intros loc; autospec M; autospec N; autospec E.
  - destruct (phi1 @ loc), (phi2 @ loc), (phi1' @ loc); auto.
    all: try solve [pose proof (proj2 (E _ _) eq_refl); congruence].
  - destruct (phi1 @ loc), (phi2 @ loc), (phi1' @ loc); auto.
    all: breakhyps.
    all: try solve [pose proof (proj1 (E _ _) eq_refl); congruence].
    injection H as <- <-.
    exists p1. f_equal. 
    try solve [pose proof (proj2 (E _ _) eq_refl); congruence].
Qed.    

Lemma pures_same_eq_r phi1 phi2 phi2' :
  level phi2 = level phi2' ->
  pures_same phi2 phi2' -> 
  pures_eq phi1 phi2 -> 
  pures_eq phi1 phi2'.
Proof.
  intros L E [M N]; split; intros loc; autospec M; autospec N; autospec E.
  - destruct (phi1 @ loc), (phi2 @ loc), (phi2' @ loc); auto; try congruence.
    all: try solve [pose proof (proj1 (E _ _) eq_refl); congruence].
  - destruct (phi1 @ loc), (phi2 @ loc), (phi2' @ loc); auto.
    all: breakhyps.
    all: try solve [pose proof (proj2 (E _ _) eq_refl); congruence].
    injection H as <- <-.
    exists p. f_equal.
    try solve [pose proof (proj2 (E _ _) eq_refl); congruence].
Qed.

Lemma pures_age_eq phi n :
  ge (level phi) n ->
  pures_eq phi (age_to n phi).
Proof.
  split; intros loc; rewrite age_to_resource_at.
  - destruct (phi @ loc); auto; simpl; do 3 f_equal; rewrite level_age_to; auto.
  - destruct (phi @ loc); simpl; eauto.
Qed.

Lemma pures_same_jm_ m tp Phi (compat : mem_compatible_with tp m Phi)
      i (cnti : containsThread tp i) :
  pures_same (m_phi (jm_ cnti compat)) Phi.
Proof.
  apply join_sub_pures_same, compatible_threadRes_sub, compat.
Qed.

Lemma level_m_phi jm : level (m_phi jm) = level jm.
Proof.
  symmetry; apply level_juice_level_phi.
Qed.

Lemma jsafeN_downward {Z} {Jspec : juicy_ext_spec Z} {ge n z c jm} :
  jsafeN Jspec ge (S n) z c jm ->
  jsafeN Jspec ge n z c jm.
Proof.
  apply safe_downward1.
Qed.

Lemma m_phi_jm_ m tp phi i cnti compat :
  m_phi (@jm_ tp m phi i cnti compat) = @getThreadR i tp cnti.
Proof.
  reflexivity.
Qed.

Definition isVAL (r : resource) :=
  match r with
  | YES _ _ (VAL _) _ => Logic.True
  | _ => False
  end.

Lemma isVAL_join_sub r1 r2 : join_sub r1 r2 -> isVAL r1 -> isVAL r2.
Proof.
  intros (r & j); inv j; simpl; tauto.
Qed.

Ltac join_sub_tac :=
  try
    match goal with
      c : mem_compatible_with ?tp ?m ?Phi |- _ =>
      match goal with
      | cnt1 : containsThread tp _,
        cnt2 : containsThread tp _,
        cnt3 : containsThread tp _,
        cnt4 : containsThread tp _ |- _ =>
        assert (join_sub (getThreadR cnt1) Phi) by (apply compatible_threadRes_sub, c);
        assert (join_sub (getThreadR cnt2) Phi) by (apply compatible_threadRes_sub, c);
        assert (join_sub (getThreadR cnt3) Phi) by (apply compatible_threadRes_sub, c);
        assert (join_sub (getThreadR cnt4) Phi) by (apply compatible_threadRes_sub, c)
      | cnt1 : containsThread tp _,
        cnt2 : containsThread tp _,
        cnt3 : containsThread tp _ |- _ =>
        assert (join_sub (getThreadR cnt1) Phi) by (apply compatible_threadRes_sub, c);
        assert (join_sub (getThreadR cnt2) Phi) by (apply compatible_threadRes_sub, c);
        assert (join_sub (getThreadR cnt3) Phi) by (apply compatible_threadRes_sub, c)
      | cnt1 : containsThread tp _,
        cnt2 : containsThread tp _ |- _ =>
        assert (join_sub (getThreadR cnt1) Phi) by (apply compatible_threadRes_sub, c);
        assert (join_sub (getThreadR cnt2) Phi) by (apply compatible_threadRes_sub, c)
      | cnt1 : containsThread tp _ |- _ =>
        assert (join_sub (getThreadR cnt1) Phi) by (apply compatible_threadRes_sub, c)
      end
    end;
  try
    match goal with
    | F : AMap.find (elt:=option rmap) ?loc (lset ?tp) = SSome ?phi,
          c : mem_compatible_with ?tp _ ?Phi |- _
      => assert (join_sub phi Phi) by eapply (@compatible_lockRes_sub tp loc phi F), c
    end;
  try
    match goal with
    | j : join ?a ?b ?c |- join_sub ?c _ => try apply (join_sub_join j)
    end;
  eauto using join_sub_trans, join_sub_join.

Lemma restrPermMap_Max' m p Hlt loc :
  access_at (@restrPermMap p m Hlt) loc Max = access_at m loc Max.
Proof.
  pose proof restrPermMap_max Hlt as R.
  apply equal_f with (x := loc) in R.
  apply R.
Qed.

Lemma restrPermMap_Cur' m p Hlt loc :
  access_at (@restrPermMap p m Hlt) loc Cur = p !! (fst loc) (snd loc).
Proof.
  apply (restrPermMap_Cur Hlt (fst loc) (snd loc)).
Qed.

Lemma juicyRestrict_ext  m phi phi' pr pr' :
  (forall loc, perm_of_res (phi @ loc) = perm_of_res (phi' @ loc)) ->
  @juicyRestrict phi m (acc_coh pr) = @juicyRestrict phi' m (acc_coh pr').
Proof.
  intros E.
  unfold juicyRestrict, juice2Perm.
  apply restrPermMap_ext; intros b.
  extensionality ofs.
  unfold mapmap in *.
  unfold "!!".
  simpl.
  do 2 rewrite PTree.gmap.
  unfold option_map in *.
  destruct (PTree.map1 _) as [|].
  - destruct (PTree.Leaf ! _) as [|]; auto.
  - destruct ((PTree.Node _ _ _) ! _) as [|]; auto.
Qed.

Lemma m_dry_personal_mem_eq m phi phi' pr pr' :
  (forall loc, perm_of_res (phi @ loc) = perm_of_res (phi' @ loc)) ->
  m_dry (@personal_mem m phi pr) =
  m_dry (@personal_mem m phi' pr').
Proof.
  intros E; simpl.
  apply juicyRestrict_ext; auto.
Qed.

Lemma matchfunspec_common_join e Gamma phi phi' psi Phi Phi' :
  join phi psi Phi ->
  join phi' psi Phi' ->
  matchfunspec e Gamma Phi ->
  matchfunspec e Gamma Phi'.
Proof.
  intros j j' M b fs.
  specialize (M b fs).
Admitted.

Tactic Notation "REWR" :=
  first
    [ unshelve erewrite <-getThreadR_age |
      unshelve erewrite gssThreadRes |
      unshelve erewrite gsoThreadRes |
      unshelve erewrite gThreadCR |
      unshelve erewrite gssAddRes |
      unshelve erewrite gsoAddRes |
      unshelve erewrite gLockSetRes |
      unshelve erewrite perm_of_age |
      unshelve erewrite gRemLockSetRes |
      unshelve erewrite m_phi_age_to
    ]; auto.

Tactic Notation "REWR" "in" hyp(H) :=
  first
    [ unshelve erewrite <-getThreadR_age in H |
      unshelve erewrite gssThreadRes in H |
      unshelve erewrite gsoThreadRes in H |
      unshelve erewrite gThreadCR in H |
      unshelve erewrite gssAddRes in H |
      unshelve erewrite gsoAddRes in H |
      unshelve erewrite gLockSetRes in H |
      unshelve erewrite perm_of_age in H |
      unshelve erewrite gRemLockSetRes in H |
      unshelve erewrite m_phi_age_to in H
    ]; auto.

Tactic Notation "REWR" "in" "*" :=
  first
    [ unshelve erewrite <-getThreadR_age in * |
      unshelve erewrite gssThreadRes in * |
      unshelve erewrite gsoThreadRes in * |
      unshelve erewrite gThreadCR in * |
      unshelve erewrite gssAddRes in * |
      unshelve erewrite gsoAddRes in * |
      unshelve erewrite gLockSetRes in * |
      unshelve erewrite perm_of_age in * |
      unshelve erewrite gRemLockSetRes in * |
      unshelve erewrite m_phi_age_to in *
    ]; auto.

Ltac lkomega :=
  unfold LKSIZE in *;
  unfold size_chunk in *;
  try omega.
