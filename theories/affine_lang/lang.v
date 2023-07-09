From gitrees Require Export lang_generic gitree program_logic.
From gitrees.input_lang Require Import lang interp.
From gitrees.examples Require Import store pairs.

(* for embedding purposes *)
Module io_lang.
  Definition state := input_lang.lang.state.
  Definition ty := input_lang.lang.ty.
  Definition expr := input_lang.lang.expr.
  Definition tyctx := tyctx ty.
  Definition typed {S} := input_lang.lang.typed (S:=S).
  Definition interp_closed {sz} (rs : gReifiers sz) `{!subReifier reify_io rs} (e : expr []) := input_lang.interp.interp_expr rs e ().
End io_lang.


Inductive ty :=
  tBool | tInt | tUnit
| tArr (τ1 τ2 : ty) | tPair (τ1 τ2 : ty)
| tRef (τ : ty).

Local Notation tyctx := (tyctx ty).

Inductive ty_conv : ty → io_lang.ty → Type :=
| ty_conv_bool : ty_conv tBool Tnat
| ty_conv_int  : ty_conv tInt  Tnat
| ty_conv_unit : ty_conv tUnit Tnat
| ty_conv_fun {τ1 τ2 t1 t2} :
  ty_conv τ1 t1 → ty_conv τ2 t2 →
  ty_conv (tArr τ1 τ2) (Tarr (Tarr Tnat t1) t2)
.

Inductive expr : scope → Type :=
| LitBool (b : bool) {S} : expr S
| LitNat (n : nat) {S} : expr S
| LitUnit {S} : expr S
| Lam {S} : expr (tt::S) → expr S
| Var {S} : var S → expr S
| App {S1 S2} : expr S1 → expr S2 → expr (S1++S2)
| EPair {S1 S2} : expr S1 → expr S2 → expr (S1++S2)
| EDestruct {S1 S2} : expr S1 → expr (()::()::S2) → expr (S1++S2)
| Alloc {S} : expr S → expr S
| Replace {S1 S2} : expr S1 → expr S2 → expr (S1++S2)
| Dealloc {S} : expr S → expr S
| EEmbed {τ1 τ1' S} : io_lang.expr [] → ty_conv τ1 τ1' → expr S
.

Section affine.
  Context {sz : nat}.
  Variable rs : gReifiers sz.
  Context `{!subReifier reify_store rs}.
  Context `{!subReifier reify_io rs}.
  Notation F := (gReifiers_ops rs).
  Notation IT := (IT F).
  Notation ITV := (ITV F).
  Context `{!invGS Σ, !stateG rs Σ, !heapG rs Σ}.
  Notation iProp := (iProp Σ).

  Program Definition thunked : IT -n> locO -n> IT := λne e ℓ,
      λit _, IF (READ ℓ) (Err OtherError)
                         (SEQ (WRITE ℓ (Nat 1)) e).
  Solve All Obligations with first [solve_proper|solve_proper_please].
  Program Definition thunkedV : IT -n> locO -n> ITV := λne e ℓ,
      FunV $ Next (λne _, IF (READ ℓ) (Err OtherError) (SEQ (WRITE ℓ (Nat 1)) e)).
  Solve All Obligations with first [solve_proper|solve_proper_please].
  #[export] Instance thunked_into_val e l : IntoVal (thunked e l) (thunkedV e l).
  Proof.
    unfold IntoVal. simpl. f_equiv. f_equiv. intro. done.
  Qed.

  Program Definition Thunk : IT -n> IT := λne e,
      ALLOC (Nat 0) (thunked e).
  Solve All Obligations with first [solve_proper|solve_proper_please].
  Program Definition Force : IT -n> IT := λne e, e ⊙ (Nat 0).

  Local Open Scope type.

  Definition nat_of_loc (l : loc) := Pos.to_nat $ encode (loc_car l).
  Definition loc_of_nat (n : nat) :=
    match decode (Pos.of_nat n) with
    | Some l => Loc l
    | None   => Loc 0%Z
    end.
  Lemma loc_of_nat_of_loc l : loc_of_nat (nat_of_loc l) = l.
  Proof.
    unfold loc_of_nat, nat_of_loc.
    rewrite Pos2Nat.id.
    rewrite decode_encode.
    by destruct l.
  Qed.

  Definition interp_litbool {A} (b : bool)  : A -n> IT := λne _,
    Nat (if b then 1 else 0).
  Definition interp_litnat {A}  (n : nat) : A -n> IT := λne _,
    Nat n.
  Definition interp_litunit {A} : A -n> IT := λne _, Nat 0.
  Program Definition interp_pair {A1 A2} (t1 : A1 -n> IT) (t2 : A2 -n> IT)
    : A1*A2 -n> IT := λne env,
    pairIT (t1 env.1) (t2 env.2).  (* we don't need to evaluate the pair here, i.e. lazy pairs? *)
  Next Obligation. solve_proper_please. Qed.
  Program Definition interp_lam {A : ofe} (b : (IT * A) -n> IT) : A -n> IT := λne env,
    λit x, b (x,env).
  Solve All Obligations with solve_proper_please.
  Program Definition interp_app {A1 A2 : ofe} (t1 : A1 -n> IT) (t2 : A2 -n> IT)
    : A1*A2 -n> IT := λne env,
    LET (t2 env.2) $ λne x,
    LET (t1 env.1) $ λne f,
    APP' f (Thunk x).
  Solve All Obligations with solve_proper_please.
  Program Definition interp_destruct {A1 A2 : ofe}
       (ps : A1 -n> IT) (t : IT*(IT*A2) -n> IT)
    : A1*A2 -n> IT := λne env,
    LET (ps env.1) $ λne ps,
    LET (Thunk (projIT1 ps)) $ λne x,
    LET (Thunk (projIT2 ps)) $ λne y,
    t (x, (y, env.2)).
  Solve All Obligations with solve_proper_please.
  Program Definition interp_alloc {A} (α : A -n> IT) : A -n> IT := λne env,
    LET (α env) $ λne α,
    ALLOC α $ λne l, Nat (nat_of_loc l).
  Solve All Obligations with solve_proper_please.
  Program Definition interp_replace {A1 A2} (α : A1 -n> IT) (β : A2 -n> IT) : A1*A2 -n> IT := λne env,
    LET (β env.2) $ λne β,
    flip get_nat (α env.1) $ λ n,
    LET (READ (loc_of_nat n)) $ λne γ,
    SEQ (WRITE (loc_of_nat n) β) (pairIT γ (Nat n)).
  Solve All Obligations with solve_proper_please.
  Program Definition interp_dealloc {A} (α : A -n> IT) : A -n> IT := λne env,
    flip get_nat (α env) $ λ n,
    DEALLOC (loc_of_nat n).
  Solve All Obligations with solve_proper_please.

  Program Definition glue_to_affine_fun (glue_from_affine glue_to_affine : IT -n> IT) : IT -n> IT := λne α,
    LET α $ λne α,
    λit xthnk,
      LET (Force xthnk) $ λne x,
      LET (glue_from_affine x) $ λne x,
      LET (α ⊙ (Thunk x)) glue_to_affine.
  Solve All Obligations with solve_proper_please.

  Program Definition glue_from_affine_fun (glue_from_affine glue_to_affine : IT -n> IT) : IT -n> IT := λne α,
    LET α $ λne α,
    LET (Thunk α) $ λne α,
    λit xthnk,
      LET (Force α) $ λne α,
      LET (Force xthnk) $ λne x,
      LET (glue_to_affine x) $ λne x,
      LET (α ⊙ (Thunk x)) glue_from_affine.
  Solve All Obligations with solve_proper_please.

  Program Definition glue2_bool : IT -n> IT := λne α,
      IF α (Nat 1) (Nat 0).

  Fixpoint glue_to_affine {τ t} (conv : ty_conv τ t) : IT -n> IT :=
    match conv with
    | ty_conv_bool => glue2_bool
    | ty_conv_int  => idfun
    | ty_conv_unit => constO (Nat 0)
    | ty_conv_fun conv1 conv2 => glue_to_affine_fun (glue_from_affine conv1) (glue_to_affine conv2)
    end
  with glue_from_affine  {τ t} (conv : ty_conv τ t) : IT -n> IT :=
    match conv with
    | ty_conv_bool => idfun
    | ty_conv_int  => idfun
    | ty_conv_unit => idfun
    | ty_conv_fun conv1 conv2 => glue_from_affine_fun (glue_from_affine conv2) (glue_to_affine conv1)
    end.


  Fixpoint interp_expr {S} (e : expr S) : interp_scope S -n> IT :=
    match e with
    | LitBool b => interp_litbool b
    | LitNat n  => interp_litnat n
    | LitUnit   => interp_litunit
    | Var v     => Force ◎ interp_var v
    | Lam e    => interp_lam (interp_expr e)
    | App e1 e2 => interp_app (interp_expr e1) (interp_expr e2) ◎ interp_scope_split
    | EPair e1 e2 => interp_pair (interp_expr e1) (interp_expr e2) ◎ interp_scope_split
    | EDestruct e1 e2 => interp_destruct (interp_expr e1) (interp_expr e2) ◎ interp_scope_split
    | Alloc e => interp_alloc (interp_expr e)
    | Dealloc e => interp_dealloc (interp_expr e)
    | Replace e1 e2 => interp_replace (interp_expr e1) (interp_expr e2) ◎ interp_scope_split
    | EEmbed e tconv =>
        constO $ glue_to_affine tconv (io_lang.interp_closed _ e)
    end.

  Lemma wp_Thunk β s Φ `{!NonExpansive Φ}:
    ⊢ heap_ctx -∗
      ▷ (∀ l, pointsto l (Nat 0) -∗ Φ (thunkedV β l)) -∗
      WP@{rs} Thunk β @ s {{ Φ }}.
  Proof.
    iIntros "#Hctx H".
    iSimpl. iApply (wp_alloc with "Hctx").
    iNext. iNext. iIntros (l) "Hl".
    iApply wp_val. iModIntro.
    iApply ("H" with "Hl").
  Qed.
End affine.

#[global] Opaque Thunk.
Arguments Force {_ _}.
Arguments Thunk {_ _ _}.
Arguments thunked {_ _ _}.
Arguments thunkedV {_ _ _}.

Arguments interp_litbool {_ _ _}.
Arguments interp_litnat {_ _ _}.
Arguments interp_litunit {_ _ _}.
Arguments interp_lam {_ _ _}.
Arguments interp_app {_ _ _ _ _}.
Arguments interp_pair {_ _ _ _}.
Arguments interp_destruct {_ _ _ _ _}.
Arguments interp_alloc {_ _ _ _}.
Arguments interp_dealloc {_ _ _ _}.
Arguments interp_replace {_ _ _ _ _}.