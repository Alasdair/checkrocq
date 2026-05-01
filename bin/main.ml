(* Copyright (c) 2026 Alasdair Armstrong *)
(* SPDX-License-Identifier: BSD-2-Clause *)

open Checkrocq
open Lexer

let find_error stderr =
  let lines = String.split_on_char '\n' stderr in
  let is_prompt_or_empty line = String.trim line = "" || String.ends_with ~suffix:"< " line in
  let rec drop_tail = function
    | [] -> []
    | line :: rest when is_prompt_or_empty line -> drop_tail rest
    | lines -> lines
  in
  let rec drop_before = function
    | [] -> None
    | line :: rest when String.starts_with ~prefix:"Error:" (String.trim line) -> (
        let error_lines = List.rev (drop_tail (List.rev (line :: rest))) in
        match error_lines with [] -> None | _ -> Some (String.concat "\n" error_lines)
      )
    | _ :: rest -> drop_before rest
  in
  drop_before lines

let usage_msg = "Usage: checkrocq <file.v> [--search <pattern>] [--name <string>]"

type search = Pattern of string | Name of string | Print of string | Command of string

let searches = ref []

let path = ref None

let color = ref "no"

let spec =
  [
    ( "--search",
      Arg.String (fun s -> searches := !searches @ [Pattern s]),
      "<pat> Search for <pat>, which can just be a lemma name."
    );
    ( "--name",
      Arg.String (fun s -> searches := !searches @ [Name s]),
      "<string> Search for lemmas and operations for which the name contains <string>."
    );
    ("--print", Arg.String (fun s -> searches := !searches @ [Print s]), "<def> Print the Rocq definition <def>.");
    ("--command", Arg.String (fun s -> searches := !searches @ [Command s]), "<command> Run the Rocq command <command>.");
    ("--color", Arg.Unit (fun () -> color := "yes"), " Cause the Rocq REPL to use colored output.");
    ("--colour", Arg.Unit (fun () -> color := "yes"), "");
  ]

let anon s = match !path with None -> path := Some s | Some _ -> raise (Arg.Bad ("unexpected argument: " ^ s))

let format_search pat =
  if String.contains pat '|' && pat.[0] <> '[' && pat.[String.length pat - 1] <> ']' then "[" ^ pat ^ "]"
  else "(" ^ pat ^ ")"

let filter_prompts output =
  String.split_on_char '\n' output
  |> List.filter (fun line ->
         let trimmed = String.trim line in
         let len = String.length trimmed in
         not (len > 0 && trimmed.[len - 1] = '<')
     )
  |> String.concat "\n"

let rec do_searches repl = function
  | [] -> ()
  | search :: rest ->
      let cmd =
        match search with
        | Pattern pat -> Printf.sprintf "Search %s." (format_search pat)
        | Name id -> Printf.sprintf "Search \"%s\"." id
        | Print id -> Printf.sprintf "Print %s." id
        | Command cmd ->
            let len = String.length cmd in
            if len > 0 && cmd.[len - 1] <> '.' then cmd ^ "." else cmd
      in
      let resp = Repl.send_command repl cmd in
      if resp.Repl.stdout <> "" then print_string resp.Repl.stdout;
      if resp.Repl.stderr <> "" then prerr_string (filter_prompts resp.Repl.stderr);
      do_searches repl rest

let rec show_last_goal_state n = function
  | [] -> ()
  | (span, resp) :: responses ->
      let out = resp.Repl.stdout in
      if String.trim out = "" then show_last_goal_state (n + 1) responses
      else if n > 0 then Printf.printf "Last goal state from line %d:\n%s\n" span.start.line resp.Repl.stdout
      else Printf.printf "Last goal state:\n%s\n" resp.Repl.stdout

let () =
  Arg.parse spec anon usage_msg;
  let path =
    match !path with
    | Some p -> p
    | None ->
        Arg.usage spec usage_msg;
        exit 1
  in
  let source = In_channel.(with_open_text path input_all) in
  let commands = commands_of_string source in
  let init_resp, repl = Repl.start ~extra_args:["-color"; !color] path in
  let rec loop responses = function
    | [] ->
        do_searches repl !searches;
        ignore (Repl.stop repl);
        exit 0
    | (span, cmd) :: rest -> (
        let resp = Repl.send_command repl cmd in
        match find_error resp.Repl.stderr with
        | Some error ->
            let code =
              match !searches with
              | [] ->
                  show_last_goal_state 0 responses;
                  Printf.printf "Command:\n%s\n\n" cmd;
                  Printf.printf "Error at line %d, character %d:\n%s" span.start.line span.start.col error;
                  1
              | _ ->
                  do_searches repl !searches;
                  0
            in
            ignore (Repl.stop repl);
            exit code
        | None -> loop ((span, resp) :: responses) rest
      )
  in
  loop [] commands
