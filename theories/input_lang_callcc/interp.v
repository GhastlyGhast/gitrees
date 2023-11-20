From Equations Require Import Equations.
From gitrees Require Import gitree.
From gitrees.input_lang_callcc Require Import lang.
Require Import gitrees.lang_generic_sem.

Require Import Binding.Lib.
Require Import Binding.Set.

Notation stateO := (leibnizO state).

Program Definition inputE : opInterp :=
  {|
    Ins := unitO;
    Outs := natO;
  |}.
Program Definition outputE : opInterp :=
  {|
    Ins := natO;
    Outs := unitO;
  |}.

Program Definition callccE : opInterp :=
  {|
    Ins := ((▶ ∙ -n> ▶ ∙) -n> ▶ ∙);
    Outs := (▶ ∙);
  |}.

Program Definition throwE : opInterp :=
  {|
    Ins := (▶ ∙ * (▶ (∙ -n> ∙)));
    Outs := Empty_setO;
  |}.

Definition ioE := @[inputE;outputE;callccE;throwE].

Definition reify_input X `{Cofe X} : unitO * stateO * (natO -n> laterO X) →
                                     option (laterO X * stateO) :=
  λ '(_, σ, k), let '(n, σ') := (update_input σ : prodO natO stateO) in
                Some (k n, σ').
#[export] Instance reify_input_ne X `{Cofe X} :
  NonExpansive (reify_input X : prodO (prodO unitO stateO)
                                  (natO -n> laterO X) →
                                  optionO (prodO (laterO X) stateO)).
Proof.
  intros n [[? σ1] k1] [[? σ2] k2]. simpl.
  intros [[_ ->] Hk]. simpl in *.
  repeat f_equiv. assumption.
Qed.

Definition reify_output X `{Cofe X} : (natO * stateO * (unitO -n> laterO X)) →
                                      optionO (prodO (laterO X) stateO) :=
  λ '(n, σ, k), Some (k (), ((update_output n σ) : stateO)).
#[export] Instance reify_output_ne X `{Cofe X} :
  NonExpansive (reify_output X : prodO (prodO natO stateO)
                                   (unitO -n> laterO X) →
                                 optionO (prodO (laterO X) stateO)).
Proof.
  intros ? [[]] [[]] []; simpl in *.
  repeat f_equiv; first assumption; apply H0.
Qed.

Definition reify_callcc X `{Cofe X} : ((laterO X -n> laterO X) -n> laterO X) *
                                        stateO * (laterO X -n> laterO X) →
                                      option (laterO X * stateO) :=
  λ '(f, σ, k), Some ((k (f k): laterO X), σ : stateO).
#[export] Instance reify_callcc_ne X `{Cofe X} :
  NonExpansive (reify_callcc X :
    prodO (prodO ((laterO X -n> laterO X) -n> laterO X) stateO)
      (laterO X -n> laterO X) →
    optionO (prodO (laterO X) stateO)).
Proof. intros ?[[]][[]][[]]. simpl in *. repeat f_equiv; auto. Qed.

Definition reify_throw X `{Cofe X} :
  ((laterO X * (laterO (X -n> X))) * stateO * (Empty_setO -n> laterO X)) →
  option (laterO X * stateO) :=
  λ '((e, k'), σ, _),
    Some (((laterO_ap k' : laterO X -n> laterO X) e : laterO X), σ : stateO).
#[export] Instance reify_throw_ne X `{Cofe X} :
  NonExpansive (reify_throw X :
      prodO (prodO (prodO (laterO X) (laterO (X -n> X))) stateO)
        (Empty_setO -n> laterO X) →
    optionO (prodO (laterO X) (stateO))).
Proof.
  intros ?[[[]]][[[]]]?. rewrite /reify_throw.
  repeat f_equiv; apply H0.
Qed.

Canonical Structure reify_io : sReifier.
Proof.
  simple refine {| sReifier_ops := ioE;
                   sReifier_state := stateO
                |}.
  intros X HX op.
  destruct op as [ | [ | [ | [| []]]]]; simpl.
  - simple refine (OfeMor (reify_input X)).
  - simple refine (OfeMor (reify_output X)).
  - simple refine (OfeMor (reify_callcc X)).
  - simple refine (OfeMor (reify_throw X)).
Defined.

Section constructors.
  Context {E : opsInterp} {A} `{!Cofe A}.
  Context {subEff0 : subEff ioE E}.
  Context {subOfe0 : SubOfe natO A}.
  Notation IT := (IT E A).
  Notation ITV := (ITV E A).


  Program Definition INPUT : (nat -n> IT) -n> IT :=
    λne k, Vis (E:=E) (subEff_opid (inl ()))
             (subEff_ins (F:=ioE) (op:=(inl ())) ())
             (NextO ◎ k ◎ (subEff_outs (F:=ioE) (op:=(inl ())))^-1).
  Solve Obligations with solve_proper.

  Program Definition OUTPUT_ : nat -n> IT -n> IT :=
    λne m α, Vis (E:=E) (subEff_opid (inr (inl ())))
                        (subEff_ins (F:=ioE) (op:=(inr (inl ()))) m)
                        (λne _, NextO α).
  Solve All Obligations with solve_proper_please.
  Program Definition OUTPUT : nat -n> IT := λne m, OUTPUT_ m (Ret 0).

  Lemma hom_INPUT k f `{!IT_hom f} : f (INPUT k) ≡ INPUT (OfeMor f ◎ k).
  Proof.
    unfold INPUT.
    rewrite hom_vis/=. repeat f_equiv.
    intro x. cbn-[laterO_map]. rewrite laterO_map_Next.
    done.
  Qed.
  Lemma hom_OUTPUT_ m α f `{!IT_hom f} : f (OUTPUT_ m α) ≡ OUTPUT_ m (f α).
  Proof.
    unfold OUTPUT.
    rewrite hom_vis/=. repeat f_equiv.
    intro x. cbn-[laterO_map]. rewrite laterO_map_Next.
    done.
  Qed.

  Program Definition CALLCC : ((laterO IT -n> laterO IT) -n> laterO IT) -n> IT :=
    λne k, Vis (E:=E) (subEff_opid (inr (inr (inl ()))))
             (subEff_ins (F:=ioE) (op:=(inr (inr (inl ())))) k)
             (λne o, (subEff_outs (F:=ioE) (op:=(inr (inr (inl ())))))^-1 o).
  Solve All Obligations with solve_proper.

  Program Definition THROW : IT -n> (laterO (IT -n> IT)) -n> IT :=
    λne m α, Vis (E:=E) (subEff_opid (inr (inr (inr (inl ())))))
               (subEff_ins (F:=ioE) (op:=(inr (inr (inr (inl ())))))
                  (NextO m, α))
               (λne _, laterO_ap α (NextO m)).
  Next Obligation.
    solve_proper.
  Qed.
  Next Obligation.
    intros; intros ???; simpl.
    repeat f_equiv; [assumption |].
    intros ?; simpl.
    apply Next_contractive.
    destruct n as [| n].
    - apply dist_later_0.
    - apply dist_later_S.
      apply dist_later_S in H.
      apply H.
  Qed.
  Next Obligation.
    intros ?????; simpl.
    repeat f_equiv; [assumption |].
    intros ?; simpl.
    repeat f_equiv; assumption.
  Qed.

End constructors.

Section weakestpre.
  Context {sz : nat}.
  Variable (rs : gReifiers sz).
  Context {subR : subReifier reify_io rs}.
  Notation F := (gReifiers_ops rs).
  Context {R} `{!Cofe R}.
  Context `{!SubOfe natO R}.
  Notation IT := (IT F R).
  Notation ITV := (ITV F R).
  Context `{!invGS Σ, !stateG rs R Σ}.
  Notation iProp := (iProp Σ).

  Lemma wp_input (σ σ' : stateO) (n : nat) (k : natO -n> IT) Φ s :
    update_input σ = (n, σ') →
    has_substate σ -∗
    ▷ (£ 1 -∗ has_substate σ' -∗ WP@{rs} (k n) @ s {{ Φ }}) -∗
    WP@{rs} (INPUT k) @ s {{ Φ }}.
  Proof.
    intros Hs. iIntros "Hs Ha".
    unfold INPUT. simpl.
    iApply (wp_subreify with "Hs").
    { simpl. by rewrite Hs. }
    { simpl. by rewrite ofe_iso_21. }
    iModIntro. done.
  Qed.

  Lemma wp_output (σ σ' : stateO) (n : nat) Φ s :
    update_output n σ = σ' →
    has_substate σ -∗
    ▷ (£ 1 -∗ has_substate σ' -∗ Φ (RetV 0)) -∗
    WP@{rs} (OUTPUT n) @ s {{ Φ }}.
  Proof.
    intros Hs. iIntros "Hs Ha".
    unfold OUTPUT. simpl.
    iApply (wp_subreify with "Hs").
    { simpl. by rewrite Hs. }
    { simpl. done. }
    iModIntro. iIntros "H1 H2".
    iApply wp_val. by iApply ("Ha" with "H1 H2").
    Unshelve. simpl; constructor.
  Qed.

End weakestpre.

Section interp.
  Context {sz : nat}.
  Variable (rs : gReifiers sz).
  Context {subR : subReifier reify_io rs}.
  Context {R} `{CR : !Cofe R}.
  Context `{!SubOfe natO R}.
  Notation F := (gReifiers_ops rs).
  Notation IT := (IT F R).
  Notation ITV := (ITV F R).

  Context {subEff0 : subEff ioE F}.
  (** Interpreting individual operators *)
  Program Definition interp_input {A} : A -n> IT :=
    λne env, INPUT Ret.
  Program Definition interp_output {A} (t : A -n> IT) : A -n> IT :=
    get_ret OUTPUT ◎ t.
  Local Instance interp_ouput_ne {A} : NonExpansive2 (@interp_output A).
  Proof. solve_proper. Qed.

  Program Definition interp_callcc {S}
    (e : @interp_scope F R _ (inc S) -n> IT) : interp_scope S -n> IT :=
    λne env, CALLCC (λne (f : laterO IT -n> laterO IT),
                       (Next (e (@extend_scope F R _ _ env
                                   (Fun (Next (λne x, Tau (f (Next x))))))))).
  Next Obligation.
    solve_proper.
  Qed.
  Next Obligation.
    solve_proper_prepare.
    repeat f_equiv.
    intros [| a]; simpl; last solve_proper.
    repeat f_equiv.
    intros ?; simpl.
    by repeat f_equiv.
  Qed.
  Next Obligation.
    solve_proper_prepare.
    repeat f_equiv.
    intros ?; simpl.
    repeat f_equiv.
    intros [| a]; simpl; last solve_proper.
    repeat f_equiv.
  Qed.

  Program Definition interp_throw {A} (n : A -n> IT) (m : A -n> IT)
    : A -n> IT :=
    λne env, get_fun (λne (f : laterO (IT -n> IT)),
                        THROW (n env) f) (m env).
  Next Obligation.
    intros ????.
    intros n' x y H.
    f_equiv; assumption.
  Qed.

  Program Definition interp_natop {A} (op : nat_op) (t1 t2 : A -n> IT) : A -n> IT :=
    λne env, NATOP (do_natop op) (t1 env) (t2 env).
  Solve All Obligations with solve_proper_please.

  Global Instance interp_natop_ne A op : NonExpansive2 (@interp_natop A op).
  Proof. solve_proper. Qed.
  Typeclasses Opaque interp_natop.

  Opaque laterO_map.
  Program Definition interp_rec_pre {S : Set} (body : @interp_scope F R _ (inc (inc S)) -n> IT)
    : laterO (@interp_scope F R _ S -n> IT) -n> @interp_scope F R _ S -n> IT :=
    λne self env, Fun $ laterO_map (λne (self : @interp_scope F R  _ S -n> IT) (a : IT),
                      body (@extend_scope F R _ _ (@extend_scope F R _ _ env (self env)) a)) self.
  Next Obligation.
    intros.
    solve_proper_prepare.
    f_equiv; intros [| [| y']]; simpl; solve_proper.
  Qed.
  Next Obligation.
    intros.
    solve_proper_prepare.
    f_equiv; intros [| [| y']]; simpl; solve_proper.
  Qed.
  Next Obligation.
    intros.
    solve_proper_prepare.
    do 3 f_equiv; intros ??; simpl; f_equiv;
    intros [| [| y']]; simpl; solve_proper.
  Qed.
  Next Obligation.
    intros.
    solve_proper_prepare.
    by do 2 f_equiv.
  Qed.

  Program Definition interp_rec {S : Set} (body : @interp_scope F R _ (inc (inc S)) -n> IT) : @interp_scope F R _ S -n> IT := mmuu (interp_rec_pre body).

  Program Definition ir_unf {S : Set} (body : @interp_scope F R _ (inc (inc S)) -n> IT) env : IT -n> IT :=
    λne a, body (@extend_scope F R _ _ (@extend_scope F R _ _ env (interp_rec body env)) a).
  Next Obligation.
    intros.
    solve_proper_prepare.
    f_equiv. intros [| [| y']]; simpl; solve_proper.
  Qed.

  Lemma interp_rec_unfold {S : Set} (body : @interp_scope F R _ (inc (inc S)) -n> IT) env :
    interp_rec body env ≡ Fun $ Next $ ir_unf body env.
  Proof.
    trans (interp_rec_pre body (Next (interp_rec body)) env).
    { f_equiv. rewrite /interp_rec. apply mmuu_unfold. }
    simpl. rewrite laterO_map_Next. repeat f_equiv.
    simpl. unfold ir_unf. intro. simpl. reflexivity.
  Qed.

  Program Definition interp_app {A} (t1 t2 : A -n> IT) : A -n> IT :=
    λne env, APP' (t1 env) (t2 env).
  Solve All Obligations with first [ solve_proper | solve_proper_please ].
  Global Instance interp_app_ne A : NonExpansive2 (@interp_app A).
  Proof. solve_proper. Qed.
  Typeclasses Opaque interp_app.

  Program Definition interp_if {A} (t0 t1 t2 : A -n> IT) : A -n> IT :=
    λne env, IF (t0 env) (t1 env) (t2 env).
  Solve All Obligations with first [ solve_proper | solve_proper_please ].
  Global Instance interp_if_ne A n :
    Proper ((dist n) ==> (dist n) ==> (dist n) ==> (dist n)) (@interp_if A).
  Proof. solve_proper. Qed.

  Program Definition interp_nat (n : nat) {A} : A -n> IT :=
    λne env, Ret n.

  Program Definition interp_cont {A} (K : A -n> (IT -n> IT)) : A -n> IT := λne env, Fun (Next (K env)).
  Solve All Obligations with solve_proper.

  Program Definition interp_applk {A} (q : A -n> IT) (K : A -n> (IT -n> IT)) : A -n> (IT -n> IT) := λne env t, interp_app q (λne env, K env t) env.
  Solve All Obligations with solve_proper.

  Program Definition interp_apprk {A} (K : A -n> (IT -n> IT)) (q : A -n> IT) : A -n> (IT -n> IT) := λne env t, interp_app (λne env, K env t) q env.
  Solve All Obligations with solve_proper.

  Program Definition interp_natoplk {A} (op : nat_op) (q : A -n> IT) (K : A -n> (IT -n> IT)) : A -n> (IT -n> IT) := λne env t, interp_natop op q (λne env, K env t) env.
  Solve All Obligations with solve_proper.

  Program Definition interp_natoprk {A} (op : nat_op) (K : A -n> (IT -n> IT)) (q : A -n> IT) : A -n> (IT -n> IT) := λne env t, interp_natop op (λne env, K env t) q env.
  Solve All Obligations with solve_proper.

  Program Definition interp_ifk {A} (K : A -n> (IT -n> IT)) (q : A -n> IT) (p : A -n> IT) : A -n> (IT -n> IT) := λne env t, interp_if (λne env, K env t) q p env.
  Solve All Obligations with solve_proper.

  Program Definition interp_outputk {A} (K : A -n> (IT -n> IT)) : A -n> (IT -n> IT) := λne env t, interp_output (λne env, K env t) env.
  Solve All Obligations with solve_proper.

  Program Definition interp_throwlk {A} (K : A -n> (IT -n> IT)) (q : A -n> IT) : A -n> (IT -n> IT) := λne env t, interp_throw (λne env, K env t) q env.
  Solve All Obligations with solve_proper_please.

  Program Definition interp_throwrk {A} (q : A -n> IT) (K : A -n> (IT -n> IT)) : A -n> (IT -n> IT) := λne env t, interp_throw q (λne env, K env t) env.
  Solve All Obligations with solve_proper_please.

  (** Interpretation for all the syntactic categories: values, expressions, contexts *)
  Fixpoint interp_val {S} (v : val S) : interp_scope S -n> IT :=
    match v with
    | LitV n => interp_nat n
    | VarV x => interp_var x
    | RecV e => interp_rec (interp_expr e)
    | ContV K => interp_cont (interp_ectx K)
    end
  with interp_expr {S} (e : expr S) : interp_scope S -n> IT :=
         match e with
         | Val v => interp_val v
         | App e1 e2 => interp_app (interp_expr e1) (interp_expr e2)
         | NatOp op e1 e2 => interp_natop op (interp_expr e1) (interp_expr e2)
         | If e e1 e2 => interp_if (interp_expr e) (interp_expr e1) (interp_expr e2)
         | Input => interp_input
         | Output e => interp_output (interp_expr e)
         | Callcc e => interp_callcc (interp_expr e)
         | Throw e1 e2 => interp_throw (interp_expr e1) (interp_expr e2)
         end
  with interp_ectx {S} (K : ectx S) : interp_scope S -n> (IT -n> IT) :=
         match K with
         | EmptyK => λne env, λne t, t
         | AppLK e1 K => interp_applk (interp_expr e1) (interp_ectx K)
         | AppRK K v2 => interp_apprk (interp_ectx K) (interp_val v2)
         | NatOpLK op e1 K => interp_natoplk op (interp_expr e1) (interp_ectx K)
         | NatOpRK op K v2 => interp_natoprk op (interp_ectx K) (interp_val v2)
         | IfK K e1 e2 => interp_ifk (interp_ectx K) (interp_expr e1) (interp_expr e2)
         | OutputK K => interp_outputk (interp_ectx K)
         | ThrowLK K e => interp_throwlk (interp_ectx K) (interp_expr e)
         | ThrowRK v K => interp_throwrk (interp_val v) (interp_ectx K)
         end.
  Solve All Obligations with first [ solve_proper | solve_proper_please ].

  Global Instance interp_val_asval {S} {D : interp_scope S} {H : ∀ (x : S), AsVal (D x)} (v : val S)
    : AsVal (interp_val v D).
  Proof.
    destruct v; simpl.
    - apply H.
    - apply _.
    - rewrite interp_rec_unfold. apply _.
    - apply _.
  Qed.

  Global Instance ArrEquiv {A B : Set} : Equiv (A [→] B) := fun f g => ∀ x, f x = g x.

  Global Instance ArrDist {A B : Set} `{Dist B} : Dist (A [→] B) := fun n => fun f g => ∀ x, f x ≡{n}≡ g x.

  Global Instance ren_scope_proper S S2 :
    Proper ((≡) ==> (≡) ==> (≡)) (@ren_scope F _ CR S S2).
  Proof.
    intros D D' HE s1 s2 Hs.
    intros x; simpl.
    f_equiv.
    - apply Hs.
    - apply HE.
 Qed.

  Lemma interp_expr_ren {S S'} env
    (δ : S [→] S') (e : expr S) :
    interp_expr (fmap δ e) env ≡ interp_expr e (ren_scope δ env)
  with interp_val_ren {S S'} env
         (δ : S [→] S') (e : val S) :
    interp_val (fmap δ e) env ≡ interp_val e (ren_scope δ env)
  with interp_ectx_ren {S S'} env
         (δ : S [→] S') (e : ectx S) :
    interp_ectx (fmap δ e) env ≡ interp_ectx e (ren_scope δ env).
  Proof.
    - destruct e; simpl.
      + by apply interp_val_ren.
      + repeat f_equiv; by apply interp_expr_ren.
      + repeat f_equiv; by apply interp_expr_ren.
      + repeat f_equiv; by apply interp_expr_ren.
      + f_equiv.
      + repeat f_equiv; by apply interp_expr_ren.
      + repeat f_equiv.
        intros ?; simpl.
        repeat f_equiv.
        simpl; rewrite interp_expr_ren.
        f_equiv.
        intros [| y]; simpl.
        * reflexivity.
        * reflexivity.
      + repeat f_equiv.
        * intros ?; simpl.
          repeat f_equiv; first by apply interp_expr_ren.
          intros ?; simpl.
          repeat f_equiv; by apply interp_expr_ren.
        * by apply interp_expr_ren.
    - destruct e; simpl.
      + reflexivity.
      + reflexivity.
      + clear -interp_expr_ren.
        apply bi.siProp.internal_eq_soundness.
        iLöb as "IH".
        rewrite {2}interp_rec_unfold.
        rewrite {2}(interp_rec_unfold (interp_expr e)).
        do 1 iApply f_equivI. iNext.
        iApply internal_eq_pointwise.
        rewrite /ir_unf. iIntros (x). simpl.
        rewrite interp_expr_ren.
        iApply f_equivI.
        iApply internal_eq_pointwise.
        iIntros (y').
        destruct y' as [| [| y]]; simpl; first done.
        * by iRewrite - "IH".
        * done.
      + repeat f_equiv.
        intros ?; simpl; by apply interp_ectx_ren.
    - destruct e; simpl; intros ?; simpl.
      + reflexivity.
      + repeat f_equiv; by apply interp_ectx_ren.
      + repeat f_equiv; [by apply interp_ectx_ren | by apply interp_expr_ren | by apply interp_expr_ren].
      + repeat f_equiv; [by apply interp_expr_ren | by apply interp_ectx_ren].
      + repeat f_equiv; [by apply interp_ectx_ren | by apply interp_val_ren].
      + repeat f_equiv; [by apply interp_expr_ren | by apply interp_ectx_ren].
      + repeat f_equiv; [by apply interp_ectx_ren | by apply interp_val_ren].
      + repeat f_equiv; last by apply interp_expr_ren.
        intros ?; simpl; repeat f_equiv; first by apply interp_ectx_ren.
        intros ?; simpl; repeat f_equiv; by apply interp_ectx_ren.
      + repeat f_equiv; last by apply interp_ectx_ren.
        intros ?; simpl; repeat f_equiv; first by apply interp_val_ren.
        intros ?; simpl; repeat f_equiv; by apply interp_val_ren.
  Qed.

  Lemma interp_comp {S} (e : expr S) (env : interp_scope S) (K : ectx S):
    interp_expr (fill K e) env ≡ (interp_ectx K) env ((interp_expr e) env).
  Proof.
    revert env.
    induction K; simpl; intros env; first reflexivity; try (by rewrite IHK).
    - repeat f_equiv.
      by rewrite IHK.
    - repeat f_equiv.
      by rewrite IHK.
    - repeat f_equiv.
      by rewrite IHK.
    - repeat f_equiv.
      intros ?; simpl.
      repeat f_equiv.
      + by rewrite IHK.
      + intros ?; simpl.
        repeat f_equiv.
        by rewrite IHK.
  Qed.

  Program Definition sub_scope {S S'} (δ : S [⇒] S') (env : interp_scope S')
    : interp_scope S := λne x, interp_val (δ x) env.

  Global Instance SubEquiv {A B : Set} : Equiv (A [⇒] B) := fun f g => ∀ x, f x = g x.

  Global Instance sub_scope_proper S S2 :
    Proper ((≡) ==> (≡) ==> (≡)) (@sub_scope S S2).
  Proof.
    intros D D' HE s1 s2 Hs.
    intros x; simpl.
    f_equiv.
    - f_equiv.
      apply HE.
    - apply Hs.
 Qed.

  Lemma interp_expr_subst {S S'} (env : interp_scope S')
    (δ : S [⇒] S') e :
    interp_expr (bind δ e) env ≡ interp_expr e (sub_scope δ env)
  with interp_val_subst {S S'} (env : interp_scope S')
         (δ : S [⇒] S') e :
    interp_val (bind δ e) env ≡ interp_val e (sub_scope δ env)
  with interp_ectx_subst {S S'} (env : interp_scope S')
         (δ : S [⇒] S') e :
    interp_ectx (bind δ e) env ≡ interp_ectx e (sub_scope δ env).
  Proof.
    - destruct e; simpl.
      + by apply interp_val_subst.
      + repeat f_equiv; by apply interp_expr_subst.
      + repeat f_equiv; by apply interp_expr_subst.
      + repeat f_equiv; by apply interp_expr_subst.
      + f_equiv.
      + repeat f_equiv; by apply interp_expr_subst.
      + repeat f_equiv.
        intros ?; simpl.
        repeat f_equiv.
        rewrite interp_expr_subst.
        f_equiv.
        intros [| x']; simpl.
        * reflexivity.
        * rewrite interp_val_ren.
          f_equiv.
          intros ?; reflexivity.
      + repeat f_equiv.
        * intros ?; simpl.
          repeat f_equiv; first by apply interp_expr_subst.
          intros ?; simpl.
          repeat f_equiv; by apply interp_expr_subst.
        * by apply interp_expr_subst.
    - destruct e; simpl.
      + term_simpl.
        reflexivity.
      + reflexivity.
      + clear -interp_expr_subst.
        apply bi.siProp.internal_eq_soundness.
        iLöb as "IH".
        rewrite {2}interp_rec_unfold.
        rewrite {2}(interp_rec_unfold (interp_expr e)).
        do 1 iApply f_equivI. iNext.
        iApply internal_eq_pointwise.
        rewrite /ir_unf. iIntros (x). simpl.
        rewrite interp_expr_subst.
        iApply f_equivI.
        iApply internal_eq_pointwise.
        iIntros (y').
        destruct y' as [| [| y]]; simpl; first done.
        * by iRewrite - "IH".
        * do 2 rewrite interp_val_ren.
          iApply f_equivI.
          iApply internal_eq_pointwise.
          iIntros (z).
          done.
      + repeat f_equiv; by apply interp_ectx_subst.
    - destruct e; simpl; intros ?; simpl.
      + reflexivity.
      + repeat f_equiv; by apply interp_ectx_subst.
      + repeat f_equiv; [by apply interp_ectx_subst | by apply interp_expr_subst | by apply interp_expr_subst].
      + repeat f_equiv; [by apply interp_expr_subst | by apply interp_ectx_subst].
      + repeat f_equiv; [by apply interp_ectx_subst | by apply interp_val_subst].
      + repeat f_equiv; [by apply interp_expr_subst | by apply interp_ectx_subst].
      + repeat f_equiv; [by apply interp_ectx_subst | by apply interp_val_subst].
      + repeat f_equiv; last by apply interp_expr_subst.
        intros ?; simpl; repeat f_equiv; first by apply interp_ectx_subst.
        intros ?; simpl; repeat f_equiv; by apply interp_ectx_subst.
      + repeat f_equiv; last by apply interp_ectx_subst.
        intros ?; simpl; repeat f_equiv; first by apply interp_val_subst.
        intros ?; simpl; repeat f_equiv; by apply interp_val_subst.
  Qed.

  (* (** ** Interpretation is a homomorphism *) *)
  #[global] Instance interp_ectx_item_hom {S} (Ki : ectx S) env :
    IT_hom (interp_ectx Ki env).
  Proof.
    destruct Ki; simpl.
  Admitted.

  (** ** Finally, preservation of reductions *)
  Lemma interp_expr_head_step {S : Set} (env : interp_scope S) (H : ∀ (x : S), AsVal (env x)) (e : expr S) e' σ σ' K n :
    head_step e σ e' σ' K (n, 0) →
    interp_expr e env ≡ Tick_n n $ interp_expr e' env.
  Proof.
    inversion 1; cbn-[IF APP' INPUT Tick get_ret2].
    - (* app lemma *)
      subst.
      erewrite APP_APP'_ITV; last apply _.
      trans (APP (Fun (Next (ir_unf (interp_expr e1) env))) (Next $ interp_val v2 env)).
      { repeat f_equiv. apply interp_rec_unfold. }
      rewrite APP_Fun. simpl. rewrite Tick_eq. do 2 f_equiv.
      simplify_eq.
      rewrite !interp_expr_subst.
      f_equiv.
      intros [| [| x]]; simpl; [| reflexivity | reflexivity].
      rewrite interp_val_ren.
      f_equiv.
      intros ?; simpl; reflexivity.
    - (* the natop stuff *)
      simplify_eq.
      destruct v1,v2; try naive_solver. simpl in *.
      rewrite NATOP_Ret.
      destruct op; simplify_eq/=; done.
    - rewrite IF_True; last lia.
      reflexivity.
    - rewrite IF_False; last lia.
      reflexivity.
  Qed.

  Lemma interp_expr_fill_no_reify {S} K (env : interp_scope S) (H : ∀ (x : S), AsVal (env x)) (e e' : expr S) σ σ' n :
    head_step e σ e' σ' K (n, 0) →
    interp_expr (fill K e) env ≡ Tick_n n $ interp_expr (fill K e') env.
  Proof.
    intros He.
    trans (interp_ectx K env (interp_expr e env)).
    { apply interp_comp. }
    trans (interp_ectx K env (Tick_n n (interp_expr e' env))).
    {
      f_equiv. apply (interp_expr_head_step env) in He.
      - apply He.
      - apply H.
    }
    trans (Tick_n n $ interp_ectx K env (interp_expr e' env)); last first.
    { f_equiv. symmetry. apply interp_comp. }
    apply hom_tick_n. apply _.
  Qed.

  Opaque INPUT OUTPUT_.
  Opaque Ret.

  Lemma interp_expr_fill_yes_reify {S} K env (e e' : expr S)
    (σ σ' : stateO) (σr : gState_rest sR_idx rs ♯ IT) n :
    head_step e σ e' σ' K (n, 1) →
    reify (gReifiers_sReifier rs)
      (interp_expr (fill K e) env)  (gState_recomp σr (sR_state σ))
      ≡ (gState_recomp σr (sR_state σ'), Tick_n n $ interp_expr (fill K e') env).
  Proof.
    intros Hst.
    trans (reify (gReifiers_sReifier rs) (interp_ectx K env (interp_expr e env))
             (gState_recomp σr (sR_state σ))).
    { f_equiv. by rewrite interp_comp. }
    inversion Hst; simplify_eq; cbn-[gState_recomp].
    - trans (reify (gReifiers_sReifier rs) (INPUT (interp_ectx K env ◎ Ret)) (gState_recomp σr (sR_state σ))).
      {
        repeat f_equiv; eauto.
        rewrite hom_INPUT. f_equiv. by intro.
      }
      rewrite reify_vis_eq //; last first.
      {
        (* rewrite subReifier_reify/=//. *)
        (* rewrite H4. done. *)
        admit.
      }
      repeat f_equiv. rewrite Tick_eq/=. repeat f_equiv.
      rewrite interp_comp.
      reflexivity.
    - trans (reify (gReifiers_sReifier rs) (interp_ectx K env (OUTPUT n0)) (gState_recomp σr (sR_state σ))).
      {
        do 3 f_equiv; eauto.
        rewrite get_ret_ret//.
      }
      trans (reify (gReifiers_sReifier rs) (OUTPUT_ n0 (interp_ectx K env (Ret 0))) (gState_recomp σr (sR_state σ))).
      {
        do 2 f_equiv; eauto.
        rewrite hom_OUTPUT_//.
      }
      rewrite reify_vis_eq //; last first.
      {
        (* rewrite subReifier_reify/=//. *)
        admit.
      }
      repeat f_equiv. rewrite Tick_eq/=. repeat f_equiv.
      rewrite interp_comp.
      reflexivity.
    - simpl.
      rewrite interp_comp.
      admit.
  Admitted.

  Lemma soundness {S} (e1 e2 : expr S) σ1 σ2 (σr : gState_rest sR_idx rs ♯ IT) n m (env : interp_scope S) (G : ∀ (x : S), AsVal (env x)) :
    prim_step e1 σ1 e2 σ2 (n,m) →
    ssteps (gReifiers_sReifier rs)
              (interp_expr e1 env) (gState_recomp σr (sR_state σ1))
              (interp_expr e2 env) (gState_recomp σr (sR_state σ2)) n.
  Proof.
    Opaque gState_decomp gState_recomp.
    inversion 1; simplify_eq/=.
    {
      destruct (head_step_io_01 _ _ _ _ _ _ _ H2); subst.
      - assert (σ1 = σ2) as ->.
        { eapply head_step_no_io; eauto. }
        eapply (interp_expr_fill_no_reify K) in H2; last done.
        rewrite H2. eapply ssteps_tick_n.
      - inversion H2;subst.
        + eapply (interp_expr_fill_yes_reify K env _ _ _ _ σr) in H2.
          rewrite interp_comp.
          rewrite hom_INPUT.
          change 1 with (Nat.add 1 0). econstructor; last first.
          { apply ssteps_zero; reflexivity. }
          eapply sstep_reify.
          { Transparent INPUT. unfold INPUT. simpl.
            f_equiv. reflexivity. }
          simpl in H2.
          rewrite -H2.
          repeat f_equiv; eauto.
          rewrite interp_comp hom_INPUT.
          eauto.
        + eapply (interp_expr_fill_yes_reify K env _ _ _ _ σr) in H2.
          rewrite interp_comp. simpl.
          rewrite get_ret_ret.
          rewrite hom_OUTPUT_.
          change 1 with (Nat.add 1 0). econstructor; last first.
          { apply ssteps_zero; reflexivity. }
          eapply sstep_reify.
          { Transparent OUTPUT_. unfold OUTPUT_. simpl.
            f_equiv. reflexivity. }
          simpl in H2.
          rewrite -H2.
          repeat f_equiv; eauto.
          Opaque OUTPUT_.
          rewrite interp_comp /= get_ret_ret hom_OUTPUT_.
          eauto.
        + admit.
    }
    {
      admit.
    }
  Admitted.

End interp.
#[global] Opaque INPUT OUTPUT_.
