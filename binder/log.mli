(*
 * log.mli
 * -------
 * Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implemtation of dbus.
 *)

val print : ('b, unit, string, unit) format4 -> 'b
  (** [print fmt] pretty print a message on [strerr] *)