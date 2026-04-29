(* Copyright (c) 2026 Alasdair Armstrong *)
(* SPDX-License-Identifier: BSD-2-Clause *)

type t = { stdin : out_channel; stdout : in_channel; stderr : in_channel; pid : int }

type response = { stdout : string; stderr : string }

(* Walk up the directory hierarchy from [path] to find the nearest directory
   containing a dune-project file. Returns [None] if none is found. *)
let find_dune_root path =
  let start = if Sys.is_directory path then path else Filename.dirname path in
  let rec loop dir =
    if Sys.file_exists (Filename.concat dir "dune-project") then Some dir
    else (
      let parent = Filename.dirname dir in
      if parent = dir then None else loop parent
    )
  in
  loop start

(* Return [path] relative to [root], assuming [path] is under [root]. *)
let relative_to root path =
  let root_slash = if root.[String.length root - 1] = '/' then root else root ^ "/" in
  let rlen = String.length root_slash in
  if String.length path >= rlen && String.sub path 0 rlen = root_slash then
    String.sub path rlen (String.length path - rlen)
  else path

let read_output ?(prompt = "< ") (repl : t) =
  let out_fd = Unix.descr_of_in_channel repl.stdout in
  let err_fd = Unix.descr_of_in_channel repl.stderr in
  let out_buf = Buffer.create 256 in
  let err_buf = Buffer.create 64 in
  let tmp = Bytes.create 4096 in
  let plen = String.length prompt in
  let ends_with_prompt () =
    let s = Buffer.contents err_buf in
    let slen = String.length s in
    slen >= plen && String.sub s (slen - plen) plen = prompt
  in
  let read_ready fds =
    List.iter
      (fun fd ->
        let n = Unix.read fd tmp 0 (Bytes.length tmp) in
        if n > 0 then Buffer.add_subbytes (if fd = out_fd then out_buf else err_buf) tmp 0 n
      )
      fds
  in
  let select fds timeout =
    let rec loop () = try Unix.select fds [] [] timeout with Unix.Unix_error (Unix.EINTR, _, _) -> loop () in
    loop ()
  in
  let rec loop () =
    if not (ends_with_prompt ()) then (
      let ready, _, _ = select [out_fd; err_fd] (-1.0) in
      read_ready ready;
      loop ()
    )
  in
  loop ();
  let rec drain_stdout () =
    let ready, _, _ = select [out_fd] 0.0 in
    if ready <> [] then (
      read_ready ready;
      drain_stdout ()
    )
  in
  drain_stdout ();
  { stdout = Buffer.contents out_buf; stderr = Buffer.contents err_buf }

let send_command ?(prompt = "< ") (repl : t) cmd =
  let cmd = String.concat " " (String.split_on_char '\n' cmd) in
  output_string repl.stdin (cmd ^ "\n");
  flush repl.stdin;
  read_output repl

let start ?(extra_args = []) path =
  let abs_path = if Filename.is_relative path then Filename.concat (Sys.getcwd ()) path else path in
  let root =
    match find_dune_root abs_path with Some r -> r | None -> failwith ("No dune-project found for: " ^ path)
  in
  let rel_file = relative_to root abs_path in
  let extra_args = match extra_args with [] -> [] | _ -> "--" :: extra_args in
  let argv = Array.of_list (["dune"; "rocq"; "top"; "--root"; root; rel_file] @ extra_args) in
  let stdin_r, stdin_w = Unix.pipe () in
  let stdout_r, stdout_w = Unix.pipe () in
  let stderr_r, stderr_w = Unix.pipe () in
  let pid = Unix.create_process "dune" argv stdin_r stdout_w stderr_w in
  Unix.close stdin_r;
  Unix.close stdout_w;
  Unix.close stderr_w;
  let repl =
    {
      stdin = Unix.out_channel_of_descr stdin_w;
      stdout = Unix.in_channel_of_descr stdout_r;
      stderr = Unix.in_channel_of_descr stderr_r;
      pid;
    }
  in
  (* Consume any intial output from starting the REPL, up to the first prompt. *)
  let resp = read_output repl in
  (resp, repl)

let stop t =
  close_out t.stdin;
  Unix.kill t.pid Sys.sigterm;
  let _, status = Unix.waitpid [] t.pid in
  close_in t.stdout;
  close_in t.stderr;
  status
