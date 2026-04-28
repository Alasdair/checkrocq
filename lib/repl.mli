(* Copyright (c) 2026 Alasdair Armstrong *)
(* SPDX-License-Identifier: BSD-2-Clause *)

type t = { stdin : out_channel; stdout : in_channel; stderr : in_channel; pid : int }

type response = { stdout : string; stderr : string }

val find_dune_root : string -> string option
val start : ?extra_args:string list -> string -> response * t

(** Send [cmd] to the REPL and collect output until [prompt] appears at the end of stdout. [prompt] defaults to ["< "],
    which matches both [Rocq < ] and [Coq < ]. The prompt is stripped from the returned [stdout]. *)
val send_command : ?prompt:string -> t -> string -> response

val stop : t -> Unix.process_status
