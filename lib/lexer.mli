(* Copyright (c) 2026 Alasdair Armstrong *)
(* SPDX-License-Identifier: BSD-2-Clause *)

type pos = { line : int; col : int }
type span = { start : pos; stop : pos }

exception Lexer_error of string

val commands_of_string : string -> (span * string) list
