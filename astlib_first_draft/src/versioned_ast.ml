open StdLabels

type t =
  { version : string
  ; ast : t Astlib_first_draft_ast.Ast.node
  }

let version t = t.version

let create ast ~version = { ast; version }

let rec iterate_to_fixed_point x ~f =
  let y = f x in
  if x == y
  then y
  else iterate_to_fixed_point y ~f

let rec convert t ~version:final_version =
  match
    Astlib_first_draft_ast.History.conversion_steps
      Astlib_first_draft_ast.History.history
      ~from_version:t.version
      ~to_version:final_version
  with
  | Some steps ->
    List.fold_left
      steps
      ~init:t.ast
      ~f:(fun ast (step : Astlib_first_draft_ast.History.conversion_step) ->
        iterate_to_fixed_point ast
          ~f:(step.conversion.f
                ~of_node:(create ~version:step.src_version)
                ~to_node:(convert ~version:step.src_version)))
  | None ->
    failwith
      (Printf.sprintf
         "cannot convert ast from version %s to version %s"
         t.version
         final_version)