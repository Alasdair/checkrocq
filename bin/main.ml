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

let usage_msg = "Usage: checkrocq <file.v> [--search <name>] [--pattern <pat>]"

type search = Pattern of string | Name of string | Print of string

let searches = ref []

let path = ref None

let color = ref "no"

let spec =
  [
    ("--pattern", Arg.String (fun s -> searches := !searches @ [Pattern s]), "<pat> Search for <pat>.");
    ("--search", Arg.String (fun s -> searches := !searches @ [Name s]), "<name> Search for lemmas involving <name>.");
    ("--print", Arg.String (fun s -> searches := !searches @ [Print s]), "<def> Print the Rocq definition <def>.");
    ("--color", Arg.Unit (fun () -> color := "yes"), " Cause the Rocq REPL to use colored output.");
    ("--colour", Arg.Unit (fun () -> color := "yes"), "");
  ]

let anon s = match !path with None -> path := Some s | Some _ -> raise (Arg.Bad ("unexpected argument: " ^ s))

let rec do_searches repl = function
  | [] -> ()
  | search :: rest ->
      let cmd =
        match search with
        | Pattern pat -> Printf.sprintf "Search (%s)." pat
        | Name id -> Printf.sprintf "Search \"%s\"." id
        | Print id -> Printf.sprintf "Print %s." id
      in
      let resp = Repl.send_command repl cmd in
      if resp.Repl.stdout <> "" then print_string resp.Repl.stdout;
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
            ( match !searches with
            | [] ->
                show_last_goal_state 0 responses;
                Printf.printf "Command:\n%s\n\n" cmd;
                Printf.printf "Error at line %d, character %d:\n%s" span.start.line span.start.col error
            | _ -> do_searches repl !searches
            );
            ignore (Repl.stop repl);
            exit 1
        | None -> loop ((span, resp) :: responses) rest
      )
  in
  loop [] commands
