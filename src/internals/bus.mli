(*
 * bus.mli
 * -------
 * Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implemtation of dbus.
 *)

(** Shared bus functions *)

val add_match : OBus_connection.t -> Match_rule.t -> unit Lwt.t
val remove_match : OBus_connection.t -> Match_rule.t -> unit Lwt.t
  (** Add/remove a match rule. These function do not wait for a reply,
      so errors are ignored. *)

val get_name_owner : OBus_connection.t -> OBus_name.bus -> OBus_name.bus option Lwt.t
  (** Get the name owner of a name. If any error happen, returns
      [None] *)