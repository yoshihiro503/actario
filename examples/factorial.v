Set Implicit Arguments.
Unset Strict Implicit.

Require Import List NPeano Actor.syntax Actor.semantics Actor.properties.
Import ListNotations.

(**
 * ref: An Algebraic Theory of Actors and its Actors and Application to a Simple Object-Based Language (Gul Agha, 2004)
 * page: 7
 *)

CoFixpoint factorial_cont_behv (val : nat) (cust : name) : behavior :=
  beh (fun msg =>
         match msg with
           | nat_msg arg =>
             cust ! nat_msg (val * arg);
             become empty_behv
           | _ => become (factorial_cont_behv val cust)
         end).

CoFixpoint factorial_behv : behavior :=
  beh (fun msg =>
         match msg with
           | tuple_msg (nat_msg 0) (name_msg cust) =>
             cust ! nat_msg 1;
             become factorial_behv
           | tuple_msg (nat_msg (S n)) (name_msg cust) =>
             cont <- new (factorial_cont_behv (S n) cust);
             me <- self;
             me ! tuple_msg (nat_msg n) (name_msg cont);
             become factorial_behv
           | _ => become factorial_behv
         end).

Definition factorial_system (n : nat) : config :=
  init "factorial" (
         x <- new factorial_behv;
         me <- self;
         x ! tuple_msg (nat_msg n) (name_msg me);
         become empty_behv
       ).

Recursive Extraction factorial_system.

Open Scope string_scope.

(* (factorial_system 0) から、(toplevel "factorial") に向けて (nat_msg 1) というメッセージが送られる遷移とそこまでの遷移列が存在する *)
(* toplevel 使って名前を指定するところが微妙 *)
Theorem deliver_1 :
  deliver_exists (factorial_system 0) (toplevel "factorial") (nat_msg 1).
Proof.
  pose (top := toplevel "factorial").
  pose (factorial := (generated top 0)).

  unfold deliver_exists.
  exists [], (become empty_behv), [], 1.
  exists [actor_state factorial (become factorial_behv) [] 0], []. (* gen_number, actors_l, actors_r とか何でも良くない？ *)
  simpl; split.
  - unfold factorial_system.
    pose (fact_actor := actor_state factorial (become factorial_behv) [] 0).
    pose (msg0 := fun me => tuple_msg (nat_msg 0) (name_msg me)).
    pose (conf1 := conf []
                        [ fact_actor;
                          actor_state top (me <- self;
                                           factorial ! (msg0 me);
                                           become empty_behv) [] 1
                        ]).
    eapply trans_trans.
    (* 遷移を1つずつ証明しないといけなくて、かなり小規模なものでも粒度細かすぎてめんどくさい。。 *)
    {
      exists New.
      assert (init "factorial" (
                     (x) <- new factorial_behv;
                     (me) <- self ;
                     (x) ! msg0 me; become empty_behv
                   ) ~(New)~> conf1).
      {
        unfold init.
        apply trans_new with (actors_l := []).
      }
      apply H.
    }
    pose (conf2 := conf []
                        [ fact_actor;
                          actor_state top (factorial ! msg0 top;
                                           become empty_behv) [] 1
                        ]).
    eapply trans_trans.
    {
      exists Self.
      assert (conf1 ~(Self)~> conf2).
      {
        apply trans_self with (actors_l := [fact_actor]).
      }
      apply H.
    }
    pose (conf3 := conf [send_message factorial (msg0 top)]
                        [ fact_actor;
                          actor_state top (become empty_behv) [] 1]).
    eapply trans_trans.
    {
      exists Send.
      assert (conf2 ~(Send)~> conf3).
      {
        apply trans_send with (actors_l := [fact_actor]).
      }
      apply H.
    }
    pose (top_actor := actor_state top (become empty_behv) [] 1).
    pose (conf4 := conf []
                        [ actor_state factorial (become factorial_behv) [msg0 top] 0;
                          top_actor]).
    eapply trans_trans.
    {
      exists Deliver.
      assert (conf3 ~(Deliver)~> conf4).
      {
        apply trans_deliver with (actors_l := []).
      }
      apply H.
    }
    pose (conf5 := conf []
                        [ actor_state factorial (top ! nat_msg 1; become factorial_behv) [] 0;
                          top_actor]).
    eapply trans_trans.
    {
      exists Open.
      assert (conf4 ~(Open)~> conf5).
      {
        apply trans_open with (actors_l := []).
      }
      apply H.
    }
    pose (conf6 := conf [send_message top (nat_msg 1)] [fact_actor; top_actor]).
    eapply trans_trans.
    {
      exists Send.
      assert (conf5 ~(Send)~> conf6).
      {
        apply trans_send with (actors_l := []).
      }
      apply H.
    }
    apply trans_refl.
  - exists (conf []
                 [ actor_state factorial (become factorial_behv) [] 0;
                   actor_state top (become empty_behv) [nat_msg 1] 1]).
    apply trans_deliver with (actors_l := [actor_state factorial (become factorial_behv) [] 0]).
Qed.
