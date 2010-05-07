(*
 * nm_ip4_config.mli
 * -----------------
 * Copyright : (c) 2010, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implementation of D-Bus.
 *)

(** Ip4 configuration *)

include OBus_proxy.Private

val addresses : t -> int list list OBus_property.r
val nameservers : t -> int list OBus_property.r
val wins_servers : t -> int list OBus_property.r
val domains : t -> string list OBus_property.r
val routes : t -> int list list OBus_property.r

type properties = {
  addresses : int list list;
  nameservers : int list;
  wins_servers : int list;
  domains : string list;
  routes : int list list;
}

val properties : t -> properties OBus_property.r
