(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(*          Xavier Leroy, INRIA Paris-Rocquencourt                     *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the INRIA Non-Commercial License Agreement.     *)
(*                                                                     *)
(* *********************************************************************)

(** Constructions of semi-lattices. *)

Require Import Coqlib.
Require Import Maps.
Require Import FSets.

(* To avoid useless definitions of inductors in extracted code. *)
Local Unset Elimination Schemes.
Local Unset Case Analysis Schemes.

(** * Signatures of semi-lattices *)

(** A semi-lattice is a type [t] equipped with an equivalence relation [eq],
  a boolean equivalence test [beq], a partial order [ge], a smallest element 
  [bot], and an upper bound operation [lub].
  Note that we do not demand that [lub] computes the least upper bound. *)

Module Type SEMILATTICE.

  Variable t: Type.
  Variable eq: t -> t -> Prop.
  Hypothesis eq_refl: forall x, eq x x.
  Hypothesis eq_sym: forall x y, eq x y -> eq y x.
  Hypothesis eq_trans: forall x y z, eq x y -> eq y z -> eq x z.
  Variable beq: t -> t -> bool.
  Hypothesis beq_correct: forall x y, beq x y = true -> eq x y.
  Variable ge: t -> t -> Prop.
  Hypothesis ge_refl: forall x y, eq x y -> ge x y.
  Hypothesis ge_trans: forall x y z, ge x y -> ge y z -> ge x z.
  Variable bot: t.
  Hypothesis ge_bot: forall x, ge x bot.
  Variable lub: t -> t -> t.
  Hypothesis ge_lub_left: forall x y, ge (lub x y) x.
  Hypothesis ge_lub_right: forall x y, ge (lub x y) y.

End SEMILATTICE.

(** A semi-lattice ``with top'' is similar, but also has a greatest
  element [top]. *)

Module Type SEMILATTICE_WITH_TOP.

  Include Type SEMILATTICE.
  Variable top: t.
  Hypothesis ge_top: forall x, ge top x.

End SEMILATTICE_WITH_TOP.

(** * Semi-lattice over maps *)

Set Implicit Arguments.

(** Given a semi-lattice with top [L], the following functor implements
  a semi-lattice structure over finite maps from positive numbers to [L.t].
  The default value for these maps is either [L.top] or [L.bot]. *)

Module LPMap(L: SEMILATTICE_WITH_TOP) <: SEMILATTICE_WITH_TOP.

Inductive t' : Type :=
  | Bot_except: PTree.t L.t -> t'
  | Top_except: PTree.t L.t -> t'.

Definition t: Type := t'.

Definition get (p: positive) (x: t) : L.t :=
  match x with
  | Bot_except m =>
      match m!p with None => L.bot | Some x => x end
  | Top_except m =>
      match m!p with None => L.top | Some x => x end
  end.

Definition set (p: positive) (v: L.t) (x: t) : t :=
  match x with
  | Bot_except m =>
      Bot_except (if L.beq v L.bot then PTree.remove p m else PTree.set p v m)
  | Top_except m =>
      Top_except (if L.beq v L.top then PTree.remove p m else PTree.set p v m)
  end.

Lemma gss:
  forall p v x,
  L.eq (get p (set p v x)) v.
Proof.
  intros. destruct x; simpl. 
  case_eq (L.beq v L.bot); intros.
  rewrite PTree.grs. apply L.eq_sym. apply L.beq_correct; auto. 
  rewrite PTree.gss. apply L.eq_refl.
  case_eq (L.beq v L.top); intros.
  rewrite PTree.grs. apply L.eq_sym. apply L.beq_correct; auto. 
  rewrite PTree.gss. apply L.eq_refl.
Qed.

Lemma gso:
  forall p q v x,
  p <> q -> get p (set q v x) = get p x.
Proof.
  intros. destruct x; simpl.
  destruct (L.beq v L.bot). rewrite PTree.gro; auto. rewrite PTree.gso; auto.
  destruct (L.beq v L.top). rewrite PTree.gro; auto. rewrite PTree.gso; auto.
Qed.

Definition eq (x y: t) : Prop :=
  forall p, L.eq (get p x) (get p y).

Lemma eq_refl: forall x, eq x x.
Proof.
  unfold eq; intros. apply L.eq_refl.
Qed.

Lemma eq_sym: forall x y, eq x y -> eq y x.
Proof.
  unfold eq; intros. apply L.eq_sym; auto.
Qed.

Lemma eq_trans: forall x y z, eq x y -> eq y z -> eq x z.
Proof.
  unfold eq; intros. eapply L.eq_trans; eauto.
Qed.

Definition beq (x y: t) : bool :=
  match x, y with
  | Bot_except m, Bot_except n => PTree.beq L.beq m n
  | Top_except m, Top_except n => PTree.beq L.beq m n
  | _, _ => false
  end.

Lemma beq_correct: forall x y, beq x y = true -> eq x y.
Proof.
  destruct x; destruct y; simpl; intro; try congruence.
  red; intro; simpl.
  generalize (PTree.beq_correct L.eq L.beq L.beq_correct t0 t1 H p).
  destruct (t0!p); destruct (t1!p); intuition. apply L.eq_refl.
  red; intro; simpl.
  generalize (PTree.beq_correct L.eq L.beq L.beq_correct t0 t1 H p).
  destruct (t0!p); destruct (t1!p); intuition. apply L.eq_refl.
Qed.

Definition ge (x y: t) : Prop :=
  forall p, L.ge (get p x) (get p y).

Lemma ge_refl: forall x y, eq x y -> ge x y.
Proof.
  unfold ge, eq; intros. apply L.ge_refl. auto.
Qed.

Lemma ge_trans: forall x y z, ge x y -> ge y z -> ge x z.
Proof.
  unfold ge; intros. apply L.ge_trans with (get p y); auto.
Qed.

Definition bot := Bot_except (PTree.empty L.t).

Lemma get_bot: forall p, get p bot = L.bot.
Proof.
  unfold bot; intros; simpl. rewrite PTree.gempty. auto.
Qed.

Lemma ge_bot: forall x, ge x bot.
Proof.
  unfold ge; intros. rewrite get_bot. apply L.ge_bot.
Qed.

Definition top := Top_except (PTree.empty L.t).

Lemma get_top: forall p, get p top = L.top.
Proof.
  unfold top; intros; simpl. rewrite PTree.gempty. auto.
Qed.

Lemma ge_top: forall x, ge top x.
Proof.
  unfold ge; intros. rewrite get_top. apply L.ge_top.
Qed.

(** A [combine] operation over the type [PTree.t L.t] that attempts
  to share its result with its arguments. *)

Section COMBINE.

Variable f: option L.t -> option L.t -> option L.t.
Hypothesis f_none_none: f None None = None.

Definition opt_eq (ox oy: option L.t) : Prop :=
  match ox, oy with
  | None, None => True
  | Some x, Some y => L.eq x y
  | _, _ => False
  end.

Lemma opt_eq_refl: forall ox, opt_eq ox ox.
Proof.
  intros. unfold opt_eq. destruct ox. apply L.eq_refl. auto. 
Qed.

Lemma opt_eq_sym: forall ox oy, opt_eq ox oy -> opt_eq oy ox.
Proof.
  unfold opt_eq. destruct ox; destruct oy; auto. apply L.eq_sym. 
Qed.

Lemma opt_eq_trans: forall ox oy oz, opt_eq ox oy -> opt_eq oy oz -> opt_eq ox oz.
Proof.
  unfold opt_eq. destruct ox; destruct oy; destruct oz; intuition. 
  eapply L.eq_trans; eauto.
Qed.

Definition opt_beq (ox oy: option L.t) : bool :=
  match ox, oy with
  | None, None => true
  | Some x, Some y => L.beq x y
  | _, _ => false
  end.

Lemma opt_beq_correct:
  forall ox oy, opt_beq ox oy = true -> opt_eq ox oy.
Proof.
  unfold opt_beq, opt_eq. destruct ox; destruct oy; try congruence. 
  intros. apply L.beq_correct; auto. 
  auto.
Qed.

Definition tree_eq (m1 m2: PTree.t L.t) : Prop :=
  forall i, opt_eq (PTree.get i m1) (PTree.get i m2).

Lemma tree_eq_refl: forall m, tree_eq m m.
Proof. intros; red; intros; apply opt_eq_refl. Qed.

Lemma tree_eq_sym: forall m1 m2, tree_eq m1 m2 -> tree_eq m2 m1.
Proof. intros; red; intros; apply opt_eq_sym; auto. Qed.

Lemma tree_eq_trans: forall m1 m2 m3, tree_eq m1 m2 -> tree_eq m2 m3 -> tree_eq m1 m3.
Proof. intros; red; intros; apply opt_eq_trans with (PTree.get i m2); auto. Qed.

Lemma tree_eq_node: 
  forall l1 o1 r1 l2 o2 r2,
  tree_eq l1 l2 -> tree_eq r1 r2 -> opt_eq o1 o2 ->
  tree_eq (PTree.Node l1 o1 r1) (PTree.Node l2 o2 r2).
Proof.
  intros; red; intros. destruct i; simpl; auto.
Qed.

Lemma tree_eq_node': 
  forall l1 o1 r1 l2 o2 r2,
  tree_eq l1 l2 -> tree_eq r1 r2 -> opt_eq o1 o2 ->
  tree_eq (PTree.Node l1 o1 r1) (PTree.Node' l2 o2 r2).
Proof.
  intros; red; intros. rewrite PTree.gnode'. apply tree_eq_node; auto. 
Qed.

Lemma tree_eq_node'': 
  forall l1 o1 r1 l2 o2 r2,
  tree_eq l1 l2 -> tree_eq r1 r2 -> opt_eq o1 o2 ->
  tree_eq (PTree.Node' l1 o1 r1) (PTree.Node' l2 o2 r2).
Proof.
  intros; red; intros. repeat rewrite PTree.gnode'. apply tree_eq_node; auto. 
Qed.

Hint Resolve opt_beq_correct opt_eq_refl opt_eq_sym 
             tree_eq_refl tree_eq_sym
             tree_eq_node tree_eq_node' tree_eq_node'' : combine.

Inductive changed: Type := Unchanged | Changed (m: PTree.t L.t).

Fixpoint combine_l (m : PTree.t L.t) {struct m} : changed :=
  match m with
  | PTree.Leaf =>
      Unchanged
  | PTree.Node l o r =>
      let o' := f o None in
      match combine_l l, combine_l r with
      | Unchanged, Unchanged => if opt_beq o' o then Unchanged else Changed (PTree.Node' l o' r)
      | Unchanged, Changed r' => Changed (PTree.Node' l o' r')
      | Changed l', Unchanged => Changed (PTree.Node' l' o' r)
      | Changed l', Changed r' => Changed (PTree.Node' l' o' r')
      end
  end.

Lemma combine_l_eq:
  forall m,
  tree_eq (match combine_l m with Unchanged => m | Changed m' => m' end)
          (PTree.xcombine_l f m).
Proof.
  induction m; simpl.
  auto with combine.
  destruct (combine_l m1) as [ | l']; destruct (combine_l m2) as [ | r'];
  auto with combine.
  case_eq (opt_beq (f o None) o); auto with combine.
Qed.

Fixpoint combine_r (m : PTree.t L.t) {struct m} : changed :=
  match m with
  | PTree.Leaf =>
      Unchanged
  | PTree.Node l o r =>
      let o' := f None o in
      match combine_r l, combine_r r with
      | Unchanged, Unchanged => if opt_beq o' o then Unchanged else Changed (PTree.Node' l o' r)
      | Unchanged, Changed r' => Changed (PTree.Node' l o' r')
      | Changed l', Unchanged => Changed (PTree.Node' l' o' r)
      | Changed l', Changed r' => Changed (PTree.Node' l' o' r')
      end
  end.

Lemma combine_r_eq:
  forall m,
  tree_eq (match combine_r m with Unchanged => m | Changed m' => m' end)
          (PTree.xcombine_r f m).
Proof.
  induction m; simpl.
  auto with combine.
  destruct (combine_r m1) as [ | l']; destruct (combine_r m2) as [ | r'];
  auto with combine.
  case_eq (opt_beq (f None o) o); auto with combine.
Qed.

Inductive changed2 : Type :=
  | Same
  | Same1
  | Same2
  | CC(m: PTree.t L.t).

Fixpoint xcombine (m1 m2 : PTree.t L.t) {struct m1} : changed2 :=
    match m1, m2 with
    | PTree.Leaf, PTree.Leaf => 
        Same
    | PTree.Leaf, _ =>
        match combine_r m2 with
        | Unchanged => Same2
        | Changed m => CC m
        end
    | _, PTree.Leaf =>
        match combine_l m1 with
        | Unchanged => Same1
        | Changed m => CC m
        end
    | PTree.Node l1 o1 r1, PTree.Node l2 o2 r2 =>
        let o := f o1 o2 in
        match xcombine l1 l2, xcombine r1 r2 with
        | Same, Same =>
            match opt_beq o o1, opt_beq o o2 with
            | true, true => Same
            | true, false => Same1
            | false, true => Same2
            | false, false => CC(PTree.Node' l1 o r1)
            end
        | Same1, Same | Same, Same1 | Same1, Same1 =>
            if opt_beq o o1 then Same1 else CC(PTree.Node' l1 o r1)
        | Same2, Same | Same, Same2 | Same2, Same2 =>
            if opt_beq o o2 then Same2 else CC(PTree.Node' l2 o r2)
        | Same1, Same2 => CC(PTree.Node' l1 o r2)
        | (Same|Same1), CC r => CC(PTree.Node' l1 o r)
        | Same2, Same1 => CC(PTree.Node' l2 o r1)
        | Same2, CC r => CC(PTree.Node' l2 o r)
        | CC l, (Same|Same1) => CC(PTree.Node' l o r1)
        | CC l, Same2 => CC(PTree.Node' l o r2)
        | CC l, CC r => CC(PTree.Node' l o r)
        end
    end.

Lemma xcombine_eq:
  forall m1 m2, 
  match xcombine m1 m2 with
  | Same => tree_eq m1 (PTree.combine f m1 m2) /\ tree_eq m2 (PTree.combine f m1 m2)
  | Same1 => tree_eq m1 (PTree.combine f m1 m2)
  | Same2 => tree_eq m2 (PTree.combine f m1 m2)
  | CC m => tree_eq m (PTree.combine f m1 m2)
  end.
Proof.
Opaque combine_l combine_r PTree.xcombine_l PTree.xcombine_r.
  induction m1; destruct m2; simpl.
  split; apply tree_eq_refl.
  generalize (combine_r_eq (PTree.Node m2_1 o m2_2)).
  destruct (combine_r (PTree.Node m2_1 o m2_2)); auto.
  generalize (combine_l_eq (PTree.Node m1_1 o m1_2)).
  destruct (combine_l (PTree.Node m1_1 o m1_2)); auto.
  generalize (IHm1_1 m2_1) (IHm1_2 m2_2). 
  destruct (xcombine m1_1 m2_1);
  destruct (xcombine m1_2 m2_2); auto with combine;
  intuition; case_eq (opt_beq (f o o0) o); case_eq (opt_beq (f o o0) o0); auto with combine.
Qed.

Definition combine (m1 m2: PTree.t L.t) : PTree.t L.t :=
  match xcombine m1 m2 with
  | Same|Same1 => m1
  | Same2 => m2
  | CC m => m
  end.

Lemma gcombine:
  forall m1 m2 i, opt_eq (PTree.get i (combine m1 m2)) (f (PTree.get i m1) (PTree.get i m2)).
Proof.
  intros.
  assert (tree_eq (combine m1 m2) (PTree.combine f m1 m2)).
  unfold combine.
  generalize (xcombine_eq m1 m2).
  destruct (xcombine m1 m2); tauto.
  eapply opt_eq_trans. apply H. rewrite PTree.gcombine; auto. apply opt_eq_refl.
Qed.

End COMBINE.

Definition opt_lub (x y: L.t) : option L.t :=
  let z := L.lub x y in
  if L.beq z L.top then None else Some z.

Definition lub (x y: t) : t :=
  match x, y with
  | Bot_except m, Bot_except n =>
      Bot_except
        (combine
           (fun a b =>
              match a, b with
              | Some u, Some v => Some (L.lub u v)
              | None, _ => b
              | _, None => a
              end)
           m n)
  | Bot_except m, Top_except n =>
      Top_except
        (combine
           (fun a b =>
              match a, b with
              | Some u, Some v => opt_lub u v
              | None, _ => b
              | _, None => None
              end)
        m n)             
  | Top_except m, Bot_except n =>
      Top_except
        (combine
           (fun a b =>
              match a, b with
              | Some u, Some v => opt_lub u v
              | None, _ => None
              | _, None => a
              end)
        m n)             
  | Top_except m, Top_except n =>
      Top_except
        (combine
           (fun a b =>
              match a, b with
              | Some u, Some v => opt_lub u v
              | _, _ => None
              end)
           m n)
  end.

Lemma gcombine_top:
  forall f t1 t2 p,
  f None None = None ->
  L.eq (get p (Top_except (combine f t1 t2)))
       (match f t1!p t2!p with Some x => x | None => L.top end).
Proof.
  intros. simpl. generalize (gcombine f H t1 t2 p). unfold opt_eq. 
  destruct ((combine f t1 t2)!p); destruct (f t1!p t2!p).
  auto. contradiction. contradiction. intros; apply L.eq_refl.
Qed.

Lemma gcombine_bot:
  forall f t1 t2 p,
  f None None = None ->
  L.eq (get p (Bot_except (combine f t1 t2)))
       (match f t1!p t2!p with Some x => x | None => L.bot end).
Proof.
  intros. simpl. generalize (gcombine f H t1 t2 p). unfold opt_eq. 
  destruct ((combine f t1 t2)!p); destruct (f t1!p t2!p).
  auto. contradiction. contradiction. intros; apply L.eq_refl.
Qed.

Lemma ge_lub_left:
  forall x y, ge (lub x y) x.
Proof.
  assert (forall u v,
    L.ge (match opt_lub u v with Some x => x | None => L.top end) u).
  intros; unfold opt_lub. 
  case_eq (L.beq (L.lub u v) L.top); intros. apply L.ge_top. apply L.ge_lub_left.

  unfold ge, lub; intros. destruct x; destruct y.

  eapply L.ge_trans. apply L.ge_refl. apply gcombine_bot. auto. 
  simpl. destruct t0!p; destruct t1!p.
  apply L.ge_lub_left.
  apply L.ge_refl. apply L.eq_refl. 
  apply L.ge_bot.
  apply L.ge_refl. apply L.eq_refl.

  eapply L.ge_trans. apply L.ge_refl. apply gcombine_top. auto. 
  simpl. destruct t0!p; destruct t1!p.
  auto.
  apply L.ge_top.
  apply L.ge_bot.
  apply L.ge_top.

  eapply L.ge_trans. apply L.ge_refl. apply gcombine_top. auto. 
  simpl. destruct t0!p; destruct t1!p.
  auto.
  apply L.ge_refl. apply L.eq_refl.
  apply L.ge_top.
  apply L.ge_top.

  eapply L.ge_trans. apply L.ge_refl. apply gcombine_top. auto. 
  simpl. destruct t0!p; destruct t1!p.
  auto.
  apply L.ge_top.
  apply L.ge_top.
  apply L.ge_top.
Qed.

Lemma ge_lub_right:
  forall x y, ge (lub x y) y.
Proof.
  assert (forall u v,
    L.ge (match opt_lub u v with Some x => x | None => L.top end) v).
  intros; unfold opt_lub. 
  case_eq (L.beq (L.lub u v) L.top); intros. apply L.ge_top. apply L.ge_lub_right.

  unfold ge, lub; intros. destruct x; destruct y.

  eapply L.ge_trans. apply L.ge_refl. apply gcombine_bot. auto. 
  simpl. destruct t0!p; destruct t1!p.
  apply L.ge_lub_right.
  apply L.ge_bot.
  apply L.ge_refl. apply L.eq_refl. 
  apply L.ge_refl. apply L.eq_refl.

  eapply L.ge_trans. apply L.ge_refl. apply gcombine_top. auto. 
  simpl. destruct t0!p; destruct t1!p.
  auto.
  apply L.ge_top.
  apply L.ge_refl. apply L.eq_refl.
  apply L.ge_top.

  eapply L.ge_trans. apply L.ge_refl. apply gcombine_top. auto. 
  simpl. destruct t0!p; destruct t1!p.
  auto.
  apply L.ge_bot.
  apply L.ge_top.
  apply L.ge_top.

  eapply L.ge_trans. apply L.ge_refl. apply gcombine_top. auto. 
  simpl. destruct t0!p; destruct t1!p.
  auto.
  apply L.ge_top.
  apply L.ge_top.
  apply L.ge_top.
Qed.

End LPMap.

(** * Semi-lattice over a set. *)

(** Given a set [S: FSetInterface.S], the following functor
    implements a semi-lattice over these sets, ordered by inclusion. *)

Module LFSet (S: FSetInterface.WS) <: SEMILATTICE.

  Definition t := S.t.

  Definition eq (x y: t) := S.Equal x y.
  Definition eq_refl: forall x, eq x x := S.eq_refl.
  Definition eq_sym: forall x y, eq x y -> eq y x := S.eq_sym.
  Definition eq_trans: forall x y z, eq x y -> eq y z -> eq x z := S.eq_trans.
  Definition beq: t -> t -> bool := S.equal.
  Definition beq_correct: forall x y, beq x y = true -> eq x y := S.equal_2.

  Definition ge (x y: t) := S.Subset y x.
  Lemma ge_refl: forall x y, eq x y -> ge x y.
  Proof.
    unfold eq, ge, S.Equal, S.Subset; intros. firstorder. 
  Qed.
  Lemma ge_trans: forall x y z, ge x y -> ge y z -> ge x z.
  Proof.
    unfold ge, S.Subset; intros. eauto.
  Qed.

  Definition  bot: t := S.empty.
  Lemma ge_bot: forall x, ge x bot.
  Proof.
    unfold ge, bot, S.Subset; intros. elim (S.empty_1 H).
  Qed.

  Definition lub: t -> t -> t := S.union.

  Lemma ge_lub_left: forall x y, ge (lub x y) x.
  Proof.
    unfold lub, ge, S.Subset; intros. apply S.union_2; auto. 
  Qed.

  Lemma ge_lub_right: forall x y, ge (lub x y) y.
  Proof.
    unfold lub, ge, S.Subset; intros. apply S.union_3; auto. 
  Qed.

End LFSet.

(** * Flat semi-lattice *)

(** Given a type with decidable equality [X], the following functor
  returns a semi-lattice structure over [X.t] complemented with
  a top and a bottom element.  The ordering is the flat ordering
  [Bot < Inj x < Top]. *) 

Module LFlat(X: EQUALITY_TYPE) <: SEMILATTICE_WITH_TOP.

Inductive t' : Type :=
  | Bot: t'
  | Inj: X.t -> t'
  | Top: t'.

Definition t : Type := t'.

Definition eq (x y: t) := (x = y).
Definition eq_refl: forall x, eq x x := (@refl_equal t).
Definition eq_sym: forall x y, eq x y -> eq y x := (@sym_equal t).
Definition eq_trans: forall x y z, eq x y -> eq y z -> eq x z := (@trans_equal t).

Definition beq (x y: t) : bool :=
  match x, y with
  | Bot, Bot => true
  | Inj u, Inj v => if X.eq u v then true else false
  | Top, Top => true
  | _, _ => false
  end.

Lemma beq_correct: forall x y, beq x y = true -> eq x y.
Proof.
  unfold eq; destruct x; destruct y; simpl; try congruence; intro.
  destruct (X.eq t0 t1); congruence.
Qed.

Definition ge (x y: t) : Prop :=
  match x, y with
  | Top, _ => True
  | _, Bot => True
  | Inj a, Inj b => a = b
  | _, _ => False
  end.

Lemma ge_refl: forall x y, eq x y -> ge x y.
Proof.
  unfold eq, ge; intros; subst y; destruct x; auto.
Qed.

Lemma ge_trans: forall x y z, ge x y -> ge y z -> ge x z.
Proof.
  unfold ge; destruct x; destruct y; try destruct z; intuition.
  transitivity t1; auto.
Qed.

Definition bot: t := Bot.

Lemma ge_bot: forall x, ge x bot.
Proof.
  destruct x; simpl; auto.
Qed.

Definition top: t := Top.

Lemma ge_top: forall x, ge top x.
Proof.
  destruct x; simpl; auto.
Qed.

Definition lub (x y: t) : t :=
  match x, y with
  | Bot, _ => y
  | _, Bot => x
  | Top, _ => Top
  | _, Top => Top
  | Inj a, Inj b => if X.eq a b then Inj a else Top
  end.

Lemma ge_lub_left: forall x y, ge (lub x y) x.
Proof.
  destruct x; destruct y; simpl; auto.
  case (X.eq t0 t1); simpl; auto.
Qed.

Lemma ge_lub_right: forall x y, ge (lub x y) y.
Proof.
  destruct x; destruct y; simpl; auto.
  case (X.eq t0 t1); simpl; auto.
Qed.

End LFlat.
  
(** * Boolean semi-lattice *)

(** This semi-lattice has only two elements, [bot] and [top], trivially
  ordered. *)

Module LBoolean <: SEMILATTICE_WITH_TOP.

Definition t := bool.

Definition eq (x y: t) := (x = y).
Definition eq_refl: forall x, eq x x := (@refl_equal t).
Definition eq_sym: forall x y, eq x y -> eq y x := (@sym_equal t).
Definition eq_trans: forall x y z, eq x y -> eq y z -> eq x z := (@trans_equal t).

Definition beq : t -> t -> bool := eqb.

Lemma beq_correct: forall x y, beq x y = true -> eq x y.
Proof eqb_prop.

Definition ge (x y: t) : Prop := x = y \/ x = true.

Lemma ge_refl: forall x y, eq x y -> ge x y.
Proof. unfold ge; tauto. Qed.

Lemma ge_trans: forall x y z, ge x y -> ge y z -> ge x z.
Proof. unfold ge; intuition congruence. Qed.

Definition bot := false.

Lemma ge_bot: forall x, ge x bot.
Proof. destruct x; compute; tauto. Qed.

Definition top := true.

Lemma ge_top: forall x, ge top x.
Proof. unfold ge, top; tauto. Qed.

Definition lub (x y: t) := x || y.

Lemma ge_lub_left: forall x y, ge (lub x y) x.
Proof. destruct x; destruct y; compute; tauto. Qed.

Lemma ge_lub_right: forall x y, ge (lub x y) y.
Proof. destruct x; destruct y; compute; tauto. Qed.

End LBoolean.
