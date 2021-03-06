(* Because other the syntax s.[x] causes trouble *)
module String = Ppxlib_caml.String
module Dyn = Dyn0

include struct
  [@@@warning "-32-3"]
  let capitalize_ascii   = String.capitalize
  let uncapitalize_ascii = String.uncapitalize
  let uppercase_ascii    = String.uppercase
  let lowercase_ascii    = String.lowercase
  let equal (a:string) b = Pervasives.(=) a b
end

include StringLabels

let compare a b = Ordering.of_int (String.compare a b)

module T = struct
  type t = StringLabels.t
  let compare = compare
  let equal (x : t) (y : t) = x = y
  let hash (s : t) = Hashtbl.hash s
end

let equal : string -> string -> bool = (=)
let hash = Hashtbl.hash
let to_sexp = Sexp.Encoder.string

let capitalize   = capitalize_ascii
let uncapitalize = uncapitalize_ascii
let uppercase    = uppercase_ascii
let lowercase    = lowercase_ascii

let break s ~pos =
  (sub s ~pos:0 ~len:pos,
   sub s ~pos ~len:(length s - pos))

let is_empty s = length s = 0

let rec check_prefix s ~prefix len i =
  i = len || s.[i] = prefix.[i] && check_prefix s ~prefix len (i + 1)

let rec check_suffix s ~suffix suffix_len offset i =
  i = suffix_len ||
  s.[offset + i] = suffix.[i] &&
  check_suffix s ~suffix suffix_len offset (i + 1)

let is_prefix s ~prefix =
  let len = length s in
  let prefix_len = length prefix in
  len >= prefix_len && (check_prefix s ~prefix prefix_len 0)

let is_suffix s ~suffix =
  let len = length s in
  let suffix_len = length suffix in
  len >= suffix_len &&
  (check_suffix s ~suffix suffix_len (len - suffix_len) 0)

let drop_prefix s ~prefix =
  if is_prefix s ~prefix then
    if length s = length prefix then
      Some ""
    else
      Some (sub s ~pos:(length prefix) ~len:(length s - length prefix))
  else
    None

let drop_suffix s ~suffix =
  if is_suffix s ~suffix then
    if length s = length suffix then
      Some s
    else
      Some (sub s ~pos:0 ~len:(length s - length suffix))
  else
    None

let extract_words s ~is_word_char =
  let rec skip_blanks i =
    if i = length s then
      []
    else if is_word_char s.[i] then
      parse_word i (i + 1)
    else
      skip_blanks (i + 1)
  and parse_word i j =
    if j = length s then
      [sub s ~pos:i ~len:(j - i)]
    else if is_word_char s.[j] then
      parse_word i (j + 1)
    else
      sub s ~pos:i ~len:(j - i) :: skip_blanks (j + 1)
  in
  skip_blanks 0

let extract_comma_space_separated_words s =
  extract_words s ~is_word_char:(function
    | ',' | ' ' | '\t' | '\n' -> false
    | _ -> true)

let extract_blank_separated_words s =
  extract_words s ~is_word_char:(function
    | ' ' | '\t' -> false
    | _ -> true)

let lsplit2 s ~on =
  match index s on with
  | exception Not_found -> None
  | i ->
    Some
      (sub s ~pos:0 ~len:i,
       sub s ~pos:(i + 1) ~len:(length s - i - 1))

let lsplit2_exn s ~on =
  match lsplit2 s ~on with
  | Some s -> s
  | None ->
    Exn.code_error "lsplit2_exn"
      [ "s", Sexp.Encoder.string s
      ; "on", Sexp.Encoder.char on
      ]

let rsplit2 s ~on =
  match rindex s on with
  | exception Not_found -> None
  | i ->
    Some
      (sub s ~pos:0 ~len:i,
       sub s ~pos:(i + 1) ~len:(length s - i - 1))

let index s ch =
  match index s ch with
  | i -> Some i
  | exception Not_found -> None

let split s ~on =
  let rec loop i j =
    if j = length s then
      [sub s ~pos:i ~len:(j - i)]
    else if s.[j] = on then
      sub s ~pos:i ~len:(j - i) :: loop (j + 1) (j + 1)
    else
      loop i (j + 1)
  in
  loop 0 0

include String_split

let escape_only c s =
  let n = ref 0 in
  let len = length s in
  for i = 0 to len - 1 do
    if unsafe_get s i = c then incr n;
  done;
  if !n = 0 then s
  else (
    let b = Bytes.create (len + !n) in
    n := 0;
    for i = 0 to len - 1 do
      if unsafe_get s i = c then (
        Bytes.unsafe_set b !n '\\';
        incr n;
      );
      Bytes.unsafe_set b !n (unsafe_get s i);
      incr n
    done;
    Bytes.unsafe_to_string b
  )

let longest_map l ~f =
  List.fold_left l ~init:0 ~f:(fun acc x ->
    max acc (length (f x)))

let longest l = longest_map l ~f:Fn.id

let longest_prefix = function
  | [] -> ""
  | [x] -> x
  | x :: xs ->
    let rec loop len i =
      if i < len && List.for_all xs ~f:(fun s -> s.[i] = x.[i]) then
        loop len (i + 1)
      else
        i
    in
    let len =
      List.fold_left ~init:(length x) ~f:(fun acc x -> min acc (length x)) xs in
    sub ~pos:0 x ~len:(loop len 0)

let exists =
  let rec loop s i len f =
    if i = len then
      false
    else
      f (unsafe_get s i) || loop s (i + 1) len f
  in
  fun s ~f ->
    loop s 0 (length s) f

let for_all =
  let rec loop s i len f =
    i = len ||
    (f (unsafe_get s i) && loop s (i + 1) len f)
  in
  fun s ~f ->
    loop s 0 (length s) f

let maybe_quoted s =
  let escaped = escaped s in
  if s == escaped || s = escaped then
    s
  else
    Printf.sprintf {|"%s"|} escaped

module Set = struct
  include Set.Make(T)
  let pp fmt t =
    Format.fprintf fmt "Set (@[%a@])"
      (Format.pp_print_list Format.pp_print_string
         ~pp_sep:(fun fmt () -> Format.fprintf fmt "@ "))
      (to_list t)

  let to_dyn t =
    let open Dyn in
    Set (List.map (to_list t) ~f:(fun x -> Dyn.String x))
end

module Map = struct
  include Map.Make(T)
  let pp f fmt t =
    Format.pp_print_list (fun fmt (k, v) ->
      Format.fprintf fmt "@[<hov 2>(%s@ =@ %a)@]" k f v
    ) fmt (to_list t)

  let to_dyn f t =
    let open Dyn in
    Map (
      to_list t
      |> List.map ~f:(fun (k ,v) -> (String k, f v))
    )
end
module Table = Hashtbl.Make(T)

let enumerate_gen s =
  let s = " " ^ s ^ " " in
  let rec loop = function
    | [] -> []
    | [x] -> [x]
    | [x; y] -> [x; s; y]
    | x :: l -> x :: ", " :: loop l
  in
  fun l -> concat (loop l) ~sep:""

let enumerate_and = enumerate_gen "and"
let enumerate_or  = enumerate_gen "or"
let enumerate_one_of = function
  | [x] -> x
  | s -> "One of " ^ enumerate_or s

let concat ~sep = function
  | [] -> ""
  | [x] -> x
  | xs -> concat ~sep xs

let take s len =
  sub s ~pos:0 ~len:(min (length s) len)

let drop s n =
  let len = length s in
  sub s ~pos:(min n len) ~len:(max (len - n) 0)

let split_n s n =
  let len = length s in
  let n = min n len in
  ( sub s ~pos:0 ~len:n
  , sub s ~pos:n ~len:(len - n)
  )

let findi =
  let rec loop s len ~f i =
    if i >= len then
      None
    else if f (String.unsafe_get s i) then
      Some i
    else
      loop s len ~f (i + 1)
  in
  fun s ~f -> loop s (String.length s) ~f 0

let rindex_opt s c =
  try Some (rindex s c) with Not_found -> None

let index_from_opt s i c =
  try Some (index_from s i c) with Not_found -> None
