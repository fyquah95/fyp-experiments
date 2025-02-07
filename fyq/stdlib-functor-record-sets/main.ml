
(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(* Sets over ordered types *)

module type OrderedType =
  sig
    type t
    val compare: t -> t -> int
  end

module type S =
  sig
    type elt
    type t
    val empty: t
    val is_empty: t -> bool
    val mem: elt -> t -> bool
    val add: elt -> t -> t
    val singleton: elt -> t
    val remove: elt -> t -> t
    val union: t -> t -> t
    val inter: t -> t -> t
    val diff: t -> t -> t
    val compare: t -> t -> int
    val equal: t -> t -> bool
    val subset: t -> t -> bool
    val iter: (elt -> unit) -> t -> unit
    val map: (elt -> elt) -> t -> t
    val fold: (elt -> 'a -> 'a) -> t -> 'a -> 'a
    val for_all: (elt -> bool) -> t -> bool
    val exists: (elt -> bool) -> t -> bool
    val filter: (elt -> bool) -> t -> t
    val partition: (elt -> bool) -> t -> t * t
    val cardinal: t -> int
    val elements: t -> elt list
    val min_elt: t -> elt
    val min_elt_opt: t -> elt option
    val max_elt: t -> elt
    val max_elt_opt: t -> elt option
    val choose: t -> elt
    val choose_opt: t -> elt option
    val split: elt -> t -> t * bool * t
    val find: elt -> t -> elt
    val find_opt: elt -> t -> elt option
    val find_first: (elt -> bool) -> t -> elt
    val find_first_opt: (elt -> bool) -> t -> elt option
    val find_last: (elt -> bool) -> t -> elt
    val find_last_opt: (elt -> bool) -> t -> elt option
    val of_list: elt list -> t
  end

module Make_set(Ord: OrderedType) =
  struct
    type elt = Ord.t
    type t = Empty | Node of {l:t; v:elt; r:t; h:int}

    (* Sets are represented by balanced binary trees (the heights of the
       children differ by at most 2 *)

    let height = function
        Empty -> 0
      | Node {h} -> h

    (* Creates a new node with left son l, value v and right son r.
       We must have all elements of l < v < all elements of r.
       l and r must be balanced and | height l - height r | <= 2.
       Inline expansion of height for better speed. *)

    let create l v r =
      let hl = match l with Empty -> 0 | Node {h} -> h in
      let hr = match r with Empty -> 0 | Node {h} -> h in
      Node{l; v; r; h=(if hl >= hr then hl + 1 else hr + 1)}

    (* Same as create, but performs one step of rebalancing if necessary.
       Assumes l and r balanced and | height l - height r | <= 3.
       Inline expansion of create for better speed in the most frequent case
       where no rebalancing is required. *)

    let bal l v r =
      let hl = match l with Empty -> 0 | Node {h} -> h in
      let hr = match r with Empty -> 0 | Node {h} -> h in
      if hl > hr + 2 then begin
        match l with
          Empty -> invalid_arg "Set.bal"
        | Node{l=ll; v=lv; r=lr} ->
            if height ll >= height lr then
              create ll lv (create lr v r)
            else begin
              match lr with
                Empty -> invalid_arg "Set.bal"
              | Node{l=lrl; v=lrv; r=lrr}->
                  create (create ll lv lrl) lrv (create lrr v r)
            end
      end else if hr > hl + 2 then begin
        match r with
          Empty -> invalid_arg "Set.bal"
        | Node{l=rl; v=rv; r=rr} ->
            if height rr >= height rl then
              create (create l v rl) rv rr
            else begin
              match rl with
                Empty -> invalid_arg "Set.bal"
              | Node{l=rll; v=rlv; r=rlr} ->
                  create (create l v rll) rlv (create rlr rv rr)
            end
      end else
        Node{l; v; r; h=(if hl >= hr then hl + 1 else hr + 1)}

    (* Insertion of one element *)

    let rec add x = function
        Empty -> Node{l=Empty; v=x; r=Empty; h=1}
      | Node{l; v; r} as t ->
          let c = Ord.compare x v in
          if c = 0 then t else
          if c < 0 then
            let ll = add x l in
            if l == ll then t else bal ll v r
          else
            let rr = add x r in
            if r == rr then t else bal l v rr

    let singleton x = Node{l=Empty; v=x; r=Empty; h=1}

    (* Beware: those two functions assume that the added v is *strictly*
       smaller (or bigger) than all the present elements in the tree; it
       does not test for equality with the current min (or max) element.
       Indeed, they are only used during the "join" operation which
       respects this precondition.
    *)

    let rec add_min_element x = function
      | Empty -> singleton x
      | Node {l; v; r} ->
        bal (add_min_element x l) v r

    let rec add_max_element x = function
      | Empty -> singleton x
      | Node {l; v; r} ->
        bal l v (add_max_element x r)

    (* Same as create and bal, but no assumptions are made on the
       relative heights of l and r. *)

    let rec join l v r =
      match (l, r) with
        (Empty, _) -> add_min_element v r
      | (_, Empty) -> add_max_element v l
      | (Node{l=ll; v=lv; r=lr; h=lh}, Node{l=rl; v=rv; r=rr; h=rh}) ->
          if lh > rh + 2 then bal ll lv (join lr v r) else
          if rh > lh + 2 then bal (join l v rl) rv rr else
          create l v r

    (* Smallest and greatest element of a set *)

    let rec min_elt = function
        Empty -> raise Not_found
      | Node{l=Empty; v} -> v
      | Node{l} -> min_elt l

    let rec min_elt_opt = function
        Empty -> None
      | Node{l=Empty; v} -> Some v
      | Node{l} -> min_elt_opt l

    let rec max_elt = function
        Empty -> raise Not_found
      | Node{v; r=Empty} -> v
      | Node{r} -> max_elt r

    let rec max_elt_opt = function
        Empty -> None
      | Node{v; r=Empty} -> Some v
      | Node{r} -> max_elt_opt r

    (* Remove the smallest element of the given set *)

    let rec remove_min_elt = function
        Empty -> invalid_arg "Set.remove_min_elt"
      | Node{l=Empty; r} -> r
      | Node{l; v; r} -> bal (remove_min_elt l) v r

    (* Merge two trees l and r into one.
       All elements of l must precede the elements of r.
       Assume | height l - height r | <= 2. *)

    let merge t1 t2 =
      match (t1, t2) with
        (Empty, t) -> t
      | (t, Empty) -> t
      | (_, _) -> bal t1 (min_elt t2) (remove_min_elt t2)

    (* Merge two trees l and r into one.
       All elements of l must precede the elements of r.
       No assumption on the heights of l and r. *)

    let concat t1 t2 =
      match (t1, t2) with
        (Empty, t) -> t
      | (t, Empty) -> t
      | (_, _) -> join t1 (min_elt t2) (remove_min_elt t2)

    (* Splitting.  split x s returns a triple (l, present, r) where
        - l is the set of elements of s that are < x
        - r is the set of elements of s that are > x
        - present is false if s contains no element equal to x,
          or true if s contains an element equal to x. *)

    let rec split x = function
        Empty ->
          (Empty, false, Empty)
      | Node{l; v; r} ->
          let c = Ord.compare x v in
          if c = 0 then (l, true, r)
          else if c < 0 then
            let (ll, pres, rl) = split x l in (ll, pres, join rl v r)
          else
            let (lr, pres, rr) = split x r in (join l v lr, pres, rr)

    (* Implementation of the set operations *)

    let empty = Empty

    let is_empty = function Empty -> true | _ -> false

    let rec mem x = function
        Empty -> false
      | Node{l; v; r} ->
          let c = Ord.compare x v in
          c = 0 || mem x (if c < 0 then l else r)

    let rec remove x = function
        Empty -> Empty
      | (Node{l; v; r} as t) ->
          let c = Ord.compare x v in
          if c = 0 then merge l r
          else
            if c < 0 then
              let ll = remove x l in
              if l == ll then t
              else bal ll v r
            else
              let rr = remove x r in
              if r == rr then t
              else bal l v rr

    let rec union s1 s2 =
      match (s1, s2) with
        (Empty, t2) -> t2
      | (t1, Empty) -> t1
      | (Node{l=l1; v=v1; r=r1; h=h1}, Node{l=l2; v=v2; r=r2; h=h2}) ->
          if h1 >= h2 then
            if h2 = 1 then add v2 s1 else begin
              let (l2, _, r2) = split v1 s2 in
              join (union l1 l2) v1 (union r1 r2)
            end
          else
            if h1 = 1 then add v1 s2 else begin
              let (l1, _, r1) = split v2 s1 in
              join (union l1 l2) v2 (union r1 r2)
            end

    let rec inter s1 s2 =
      match (s1, s2) with
        (Empty, _) -> Empty
      | (_, Empty) -> Empty
      | (Node{l=l1; v=v1; r=r1}, t2) ->
          match split v1 t2 with
            (l2, false, r2) ->
              concat (inter l1 l2) (inter r1 r2)
          | (l2, true, r2) ->
              join (inter l1 l2) v1 (inter r1 r2)

    let rec diff s1 s2 =
      match (s1, s2) with
        (Empty, _) -> Empty
      | (t1, Empty) -> t1
      | (Node{l=l1; v=v1; r=r1}, t2) ->
          match split v1 t2 with
            (l2, false, r2) ->
              join (diff l1 l2) v1 (diff r1 r2)
          | (l2, true, r2) ->
              concat (diff l1 l2) (diff r1 r2)

    type enumeration = End | More of elt * t * enumeration

    let rec cons_enum s e =
      match s with
        Empty -> e
      | Node{l; v; r} -> cons_enum l (More(v, r, e))

    let rec compare_aux e1 e2 =
        match (e1, e2) with
        (End, End) -> 0
      | (End, _)  -> -1
      | (_, End) -> 1
      | (More(v1, r1, e1), More(v2, r2, e2)) ->
          let c = Ord.compare v1 v2 in
          if c <> 0
          then c
          else compare_aux (cons_enum r1 e1) (cons_enum r2 e2)

    let compare s1 s2 =
      compare_aux (cons_enum s1 End) (cons_enum s2 End)

    let equal s1 s2 =
      compare s1 s2 = 0

    let rec subset s1 s2 =
      match (s1, s2) with
        Empty, _ ->
          true
      | _, Empty ->
          false
      | Node {l=l1; v=v1; r=r1}, (Node {l=l2; v=v2; r=r2} as t2) ->
          let c = Ord.compare v1 v2 in
          if c = 0 then
            subset l1 l2 && subset r1 r2
          else if c < 0 then
            subset (Node {l=l1; v=v1; r=Empty; h=0}) l2 && subset r1 t2
          else
            subset (Node {l=Empty; v=v1; r=r1; h=0}) r2 && subset l1 t2

    let rec iter f = function
        Empty -> ()
      | Node{l; v; r} -> iter f l; f v; iter f r

    let rec fold f s accu =
      match s with
        Empty -> accu
      | Node{l; v; r} -> fold f r (f v (fold f l accu))

    let rec for_all p = function
        Empty -> true
      | Node{l; v; r} -> p v && for_all p l && for_all p r

    let rec exists p = function
        Empty -> false
      | Node{l; v; r} -> p v || exists p l || exists p r

    let rec filter p = function
        Empty -> Empty
      | (Node{l; v; r}) as t ->
          (* call [p] in the expected left-to-right order *)
          let l' = filter p l in
          let pv = p v in
          let r' = filter p r in
          if pv then
            if l==l' && r==r' then t else join l' v r'
          else concat l' r'

    let rec partition p = function
        Empty -> (Empty, Empty)
      | Node{l; v; r} ->
          (* call [p] in the expected left-to-right order *)
          let (lt, lf) = partition p l in
          let pv = p v in
          let (rt, rf) = partition p r in
          if pv
          then (join lt v rt, concat lf rf)
          else (concat lt rt, join lf v rf)

    let rec cardinal = function
        Empty -> 0
      | Node{l; r} -> cardinal l + 1 + cardinal r

    let rec elements_aux accu = function
        Empty -> accu
      | Node{l; v; r} -> elements_aux (v :: elements_aux accu r) l

    let elements s =
      elements_aux [] s

    let choose = min_elt

    let choose_opt = min_elt_opt

    let rec find x = function
        Empty -> raise Not_found
      | Node{l; v; r} ->
          let c = Ord.compare x v in
          if c = 0 then v
          else find x (if c < 0 then l else r)

    let rec find_first_aux v0 f = function
        Empty ->
          v0
      | Node{l; v; r} ->
          if f v then
            find_first_aux v f l
          else
            find_first_aux v0 f r

    let rec find_first f = function
        Empty ->
          raise Not_found
      | Node{l; v; r} ->
          if f v then
            find_first_aux v f l
          else
            find_first f r

    let rec find_first_opt_aux v0 f = function
        Empty ->
          Some v0
      | Node{l; v; r} ->
          if f v then
            find_first_opt_aux v f l
          else
            find_first_opt_aux v0 f r

    let rec find_first_opt f = function
        Empty ->
          None
      | Node{l; v; r} ->
          if f v then
            find_first_opt_aux v f l
          else
            find_first_opt f r

    let rec find_last_aux v0 f = function
        Empty ->
          v0
      | Node{l; v; r} ->
          if f v then
            find_last_aux v f r
          else
            find_last_aux v0 f l

    let rec find_last f = function
        Empty ->
          raise Not_found
      | Node{l; v; r} ->
          if f v then
            find_last_aux v f r
          else
            find_last f l

    let rec find_last_opt_aux v0 f = function
        Empty ->
          Some v0
      | Node{l; v; r} ->
          if f v then
            find_last_opt_aux v f r
          else
            find_last_opt_aux v0 f l

    let rec find_last_opt f = function
        Empty ->
          None
      | Node{l; v; r} ->
          if f v then
            find_last_opt_aux v f r
          else
            find_last_opt f l

    let rec find_opt x = function
        Empty -> None
      | Node{l; v; r} ->
          let c = Ord.compare x v in
          if c = 0 then Some v
          else find_opt x (if c < 0 then l else r)

    let try_join l v r =
      (* [join l v r] can only be called when (elements of l < v <
         elements of r); use [try_join l v r] when this property may
         not hold, but you hope it does hold in the common case *)
      if (l = Empty || Ord.compare (max_elt l) v < 0)
      && (r = Empty || Ord.compare v (min_elt r) < 0)
      then join l v r
      else union l (add v r)

    let rec map f = function
      | Empty -> Empty
      | Node{l; v; r} as t ->
         (* enforce left-to-right evaluation order *)
         let l' = map f l in
         let v' = f v in
         let r' = map f r in
         if l == l' && v == v' && r == r' then t
         else try_join l' v' r'

    let of_sorted_list l =
      let rec sub n l =
        match n, l with
        | 0, l -> Empty, l
        | 1, x0 :: l -> Node {l=Empty; v=x0; r=Empty; h=1}, l
        | 2, x0 :: x1 :: l ->
            Node{l=Node{l=Empty; v=x0; r=Empty; h=1}; v=x1; r=Empty; h=2}, l
        | 3, x0 :: x1 :: x2 :: l ->
            Node{l=Node{l=Empty; v=x0; r=Empty; h=1}; v=x1;
                 r=Node{l=Empty; v=x2; r=Empty; h=1}; h=2}, l
        | n, l ->
          let nl = n / 2 in
          let left, l = sub nl l in
          match l with
          | [] -> assert false
          | mid :: l ->
            let right, l = sub (n - nl - 1) l in
            create left mid right, l
      in
      fst (sub (List.length l) l)

    let of_list l =
      match l with
      | [] -> empty
      | [x0] -> singleton x0
      | [x0; x1] -> add x1 (singleton x0)
      | [x0; x1; x2] -> add x2 (add x1 (singleton x0))
      | [x0; x1; x2; x3] -> add x3 (add x2 (add x1 (singleton x0)))
      | [x0; x1; x2; x3; x4] -> add x4 (add x3 (add x2 (add x1 (singleton x0))))
      | _ -> of_sorted_list (List.sort_uniq Ord.compare l)
  end

let rec until_first_not_zero l =
  match l with
  | [] -> 0
  | hd :: tl ->
    let ret = hd () in
    if ret <> 0 then
      ret
    else
      until_first_not_zero tl
;;

let int_compare a b =
  if a < b then -1
  else if a = b then 0
  else 1
;;

let float_compare (a : float) (b : float) =
  if a < b then -1
  else if a = b then 0
  else 1
;;

module Make_t(M : sig
  type t

  val compare : t -> t -> int
end) = struct

  type descr = M.t

  type t =
    { created_at : int;
      updated_at : int;
      name       : string;
      id         : int;
      data       : descr;
    }

  let compare a b = 
    until_first_not_zero [
      (fun () -> int_compare a.created_at b.created_at);
      (fun () -> int_compare a.updated_at b.updated_at);
      (fun () -> String.compare a.name b.name);
      (fun () -> int_compare a.id b.id);
      (fun () -> M.compare a.data b.data);
    ]
  ;;
end

module Descr = struct
  type t =
    { height    : int;
      weight    : int;
      rating    : float;
    }

  let compare a b =
    until_first_not_zero [
      (fun () -> int_compare a.height b.height);
      (fun () -> int_compare a.weight b.weight);
      (fun () -> float_compare a.rating b.rating);
    ]
  ;;
end

module T = Make_t(Descr)

module Set = Make_set(T)

external print_int_native : int -> unit = "caml_print_int_native"

let gen_t () =
   let height = 170 + Random.int 30 in
   let weight = 170 + Random.int 30 in
   let rating  = Random.float 1.0 in
   let data = { Descr. height; weight; rating; } in
     { T.
       created_at = Random.int 100000;
       updated_at = Random.int 100000;
       name = "name_" ^ string_of_int (Random.int 10000);
       id  = Random.int 100000;
       data;
     }
;;

let () =
  (* Initialise sets to random shit *)
  Random.init 10;

  (* This simulated two job queues getting jobs and a single executor,
   * using the [task] field as a call back function
   *)
  let rec loop ~ctr ~acc =
    if ctr = 0 then
      acc
    else
      if ctr = 0 then acc
      else
        loop ~ctr:(ctr - 1) ~acc:(Set.add (gen_t ()) acc)
  in
  let set1 = loop ~ctr:800000 ~acc:Set.empty in
  let set2 = loop ~ctr:800000 ~acc:Set.empty in
  let set_diff = Set.diff set1 set2 in
  let module Stats = struct
    type acc = (int * float)

    type t =
      { height : acc;
        weight : acc;
        rating : acc;
      }

    let empty =
      { height = (0, 0.0);
        weight = (0, 0.0);
        rating = (0, 0.0);
      }
  end
  in
  print_int_native (Set.cardinal set_diff);
  let set_union = Set.union set1 set2 in
  let add (ctr, total) x = (ctr + 1, total +. x) in
  let of_int = float_of_int in
  let (fold_res : Stats.t) = 
    Set.fold (fun entry (u : Stats.t) ->
        let ret = u in
        let ret =
          { ret with height = add u.height (of_int entry.data.height) }
        in
        let ret =
          { ret with weight = add u.weight (of_int entry.data.weight) }
        in
        let ret = { ret with rating = add u.rating entry.data.rating } in
        ret)
      set_union
      Stats.empty
  in
  let avg (ctr, total) = int_of_float total / ctr in
  print_int_native (avg (fold_res.height));
  print_int_native (avg (fold_res.weight));
  print_int_native (avg (fold_res.rating));
  ()
;;

let () =
  try
    let fn = Sys.getenv "OCAML_GC_STATS" in
    let oc = open_out fn in
    Gc.print_stat oc
  with _ -> ()
