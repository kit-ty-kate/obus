(*
 * util.mli
 * --------
 * Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implemtation of dbus.
 *)

include Common_util_interf.S

val with_mutex : ThreadImplem.Mutex.t -> (unit -> 'a) -> 'a
