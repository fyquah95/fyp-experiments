(** lu.ml --- LU decompisition by Crout's method

    [MIT License] Copyright (C) 2015 Akinori ABE
*)

open Format


let init_matrix m n f = Array.init m (fun i -> Array.init n (f i))

let matrix_size a =
  let m = Array.length a in
  let n = if m = 0 then 0 else Array.length a.(0) in
  (m, n)

(** [swap x i j] swaps [x.(i)] and [x.(j)]. *)
let swap x i j =
  let tmp = x.(i) in
  x.(i) <- x.(j);
  x.(j) <- tmp


(** [foldi f init i j] is [f (... (f (f init i) (i+1)) ...) j]. *)
let foldi f init i j =
  let acc = ref init in
  for k = i to j do acc := f !acc k done;
  !acc

(** [sumi f i j] is [f i +. f (i+1) +. ... +. f j] *)
let sumi f i j = foldi (fun acc k -> acc +. f k) 0.0 i j

(** [maxi f i j] computes the index of the maximum in [f i, f (i+1), ..., f j].
*)
let maxi f i j =
  foldi
    (fun (k0, v0) k -> let v = f k in if v0 < v then (k, v) else (k0, v0))
    (-1, ~-. max_float) i j
  |> fst

(** [lup a] computes LUP decomposition of square matrix [a] by Crout's method.
    @return [(p, lu)] where [p] is an array of permutation indices and [lu] is
    a matrix containing lower and upper triangular matrices.
*)
let lup a0 =
  let a = Array.copy a0 in
  let m, n = matrix_size a in
  let r = min m n in
  let p = Array.init m (fun i -> i) in (* permutation indices *)
  let lu = Array.make_matrix m n 0.0 in
  let aux i j q = a.(i).(j) -. sumi (fun k -> lu.(i).(k) *. lu.(k).(j)) 0 q in
  let get_pivot j = maxi (fun i -> abs_float a.(i).(j)) j (m-1) in
  for j = 0 to r - 1 do
    (* pivot selection (swapping rows) *)
    let j' = get_pivot j in
    if j <> j' then Array.(swap p j j' ; swap a j j' ; swap lu j j');
    (* Compute LU decomposition *)
    for i = 0 to j do lu.(i).(j) <- aux i j (i-1) done;
    if abs_float lu.(j).(j) > 1e-6 (* Avoid divsion by zero *)
    then for i = j+1 to m-1 do lu.(i).(j) <- aux i j (j-1) /. lu.(j).(j) done
  done;
  (* Compute the right block in the upper trapezoidal matrix *)
  for j = r to n-1 do
    for i = 0 to r-1 do lu.(i).(j) <- aux i j (i-1) done
  done;
  (p, lu)

(** Matrix multiplication *)
let gemm x y =
  let m, k = matrix_size x in
  let k', n = matrix_size y in
  assert(k = k');
  init_matrix m n
    (fun i j -> sumi (fun l -> x.(i).(l) *. y.(l).(j)) 0 (k - 1))

let print_mat label x =
  printf "%s =@\n" label;
  Array.iter (fun xi ->
      Array.iter (printf "  %10g") xi;
      print_newline ()) x

let main () =
  let len = Sys.argv.(1) |> int_of_string in
  let a =
    Array.init len (fun _ ->
      Array.init len (fun _ -> Random.float 10.0 -. 5.0))
  in
  let p, lu = lup a in
  let m, n = matrix_size lu in
  let r = min m n in
  let l = (* a lower trapezoidal matrix *)
    init_matrix m r
      (fun i j -> if i > j then lu.(i).(j) else if i = j then 1.0 else 0.0) in
  let u = (* an upper trapezoidal matrix *)
    init_matrix r n
      (fun i j -> if i <= j then lu.(i).(j) else 0.0) in
  let p = (* a permutation matrix *)
    init_matrix m m (fun i j -> if i = p.(j) then 1.0 else 0.0) in
  let a' = gemm p (gemm l u) in (* ['a] is equal to [a]. *)
  (* print_mat "matrix A" a; *)
  (* print_mat "matrix L" l; *)
  (* print_mat "matrix U" u; *)
  (* print_mat "matrix P" p; *)
  (* print_mat "matrix P * L * U" a' *)
  a'

let () =
  let _ = main () in
  try
    let fn = Sys.getenv "OCAML_GC_STATS" in
    let oc = open_out fn in
    Gc.print_stat oc
  with _ -> ()
;;
