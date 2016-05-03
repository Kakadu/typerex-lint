open Std_utils
open Sempatch

let test_progs = [
  "x", [ "simpleVar", "y" ];
  "f x y", [ "apply", "foo y"];
  "x", [ "patch1", "((+) x) 1" ];
  "fun x -> x", [ "patch1", "fun x  -> ((+) x) 1"; "functionMatch", "foo"];
  "let x = 1 in x", [ "letBinding", "tralala"; "replaceInsideLet", "let x = 1 in y"];
  "1, 2, 3, 4", [ "tuples", "foo"];
  "if List.length mylist = 0 then foo else bar", [ "listCompare", "match mylist with | [] -> foo | _ -> bar" ];
  "function | foo -> true | bar -> true", [ "function", "function | foo -> true | bar -> false"];
  "match x with foo -> true | bar -> false", [ "match", "x = foo" ];
  "match x with Some y -> true | None -> false", [ "matchPattern", "Option.is_some x" ]
]

let in_file = open_in Sys.argv.(1)

let patches = Patch.from_channel in_file

let string_to_expr s = Parser.parse_expression Lexer.token (Lexing.from_string s)
let expr_to_string e =
  Pprintast.expression Format.str_formatter e;
  Format.flush_str_formatter ()

let dump_env patch_name env =
  Printf.eprintf "==========\n%s : \n" patch_name;
      List.iter (fun (key, value) ->
          let dump =
            Ast_element.to_string value
          in
          Printf.eprintf "[%s=%s]" key dump
        )
        (Substitution.to_list (Match.get_substitutions env));
      Printf.eprintf "\n"

let test patches (ast, expected_results) =
  let parsed_ast = string_to_expr ast in
  List.fold_left (fun accu patch ->
    List.map (fun (name, expected) ->
        if (name = Patch.get_name patch) then
          let patched_ast, matches = Patch.apply patch (Ast_element.Expression parsed_ast) in
          List.iter (dump_env name) matches;
          let pp_parsed_ast = Ast_element.to_string patched_ast in
          Option.some_if (expected <> pp_parsed_ast) (name, pp_parsed_ast)
        else None
        )
    expected_results
    :: accu
  )
  []
  patches
  |> List.flatten

let () =
  let failure = ref false in
  List.map (test patches) test_progs
  |> List.iteri
       (fun i -> List.iter
          (fun ast_opt -> match ast_opt with
            | Some (name, ast) ->
              Printf.printf "Error applying patch %s at test %d : got " name i;
              failure := true;
              print_endline ast
            | None -> ()
          )
       );
  close_in in_file;
  if !failure
  then
    exit 1
  else
    exit 0