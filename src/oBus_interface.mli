(*
 * oBus_interface.mli
 * ------------------
 * Copyright : (c) 2008, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implemtation of dbus.
 *)

(** Proxy interface definition *)

(** This is the ocaml version of a DBus interface for proxy code.

    Note that interface contained in XML introspection files can be
    automatically converted with [obus-binder] *)
module type S = sig
  type t

  val interface : OBus_name.interface
    (** Name of the interface *)

  val method_call : OBus_name.member -> ('a, 'b Lwt.t, 'b) OBus_type.func -> t -> 'a
    (** [call member typ obj ...] define a method call.

        A method call definition looks like:

        {[
          let caml_name = call "DBusName" method_call_type
        ]}

        Or even simpler, with the syntax extension:

        {[
          OBUS_method DBusName : method_call_type
        ]}
    *)

  val signal : ?broadcast:bool -> OBus_name.member -> ('a, _) OBus_type.cl_sequence -> t -> 'a OBus_signal.t
    (** [signal ?broadcast member typ proxy] define a signal.

        A signal defintion looks like:

        {[
          let caml_name1 = signal "DBusName1" signal_type
          let caml_name2 = signal ~broadcast:false "DBusName2" signal_type
        ]}

        Or, with the syntax extension:

        {[
          OBUS_signal DBusName1 : signal_type
          OBUS_signal! DBusName2 : signal_type
        ]}
    *)

  val property : OBus_name.member -> 'mode OBus_property.access -> ('a, _) OBus_type.cl_single -> t -> ('a, 'mode) OBus_property.t
    (** [property member access typ proxy] define a property.

        A property definition looks like:

        {[
          let caml_name = property "DBusName" OBus_property.rd_only property_type
          let caml_name = property "DBusName" OBus_property.wr_only property_type
          let caml_name = property "DBusName" OBus_property.rdwr property_type
        ]}

        Or, with the syntax extension:

        {[
          OBUS_property_r DBusName : property_type
          OBUS_property_w DBusName : property_type
          OBUS_property_rw DBusName : property_type
        ]}
    *)

  val property_r : OBus_name.member -> ('a, _) OBus_type.cl_single -> t -> ('a, [ `readable ]) OBus_property.t
  val property_w : OBus_name.member -> ('a, _) OBus_type.cl_single -> t -> ('a, [ `writable ]) OBus_property.t
  val property_rw : OBus_name.member -> ('a, _) OBus_type.cl_single -> t -> ('a, [ `readable | `writable ]) OBus_property.t
end

(** Name of an interface *)
module type Name = sig
  val name : OBus_name.interface
end

module Make(Name : Name) : S with type t = OBus_proxy.t

(** {6 Interface using a custom proxy type} *)

module type Custom_proxy = sig
  type t
  val make_proxy : t -> OBus_proxy.t Lwt.t
end

module Make_custom(Proxy : Custom_proxy)(Name : Name) : S with type t = Proxy.t

(** {6 Interface for a single object} *)

module type Single_proxy = sig
  val proxy : OBus_proxy.t Lwt.t Lazy.t
end

module Make_single(Proxy : Single_proxy)(Name : Name) : sig
  val interface : OBus_name.interface
  val method_call : OBus_name.member -> ('a, 'b Lwt.t, 'b) OBus_type.func -> 'a
  val signal : ?broadcast:bool -> OBus_name.member -> ('a, _) OBus_type.cl_sequence -> 'a OBus_signal.t
  val property : OBus_name.member -> 'mode OBus_property.access -> ('a, _) OBus_type.cl_single -> ('a, 'mode) OBus_property.t
  val property_r : OBus_name.member -> ('a, _) OBus_type.cl_single -> ('a, [ `readable ]) OBus_property.t
  val property_w : OBus_name.member -> ('a, _) OBus_type.cl_single -> ('a, [ `writable ]) OBus_property.t
  val property_rw : OBus_name.member -> ('a, _) OBus_type.cl_single -> ('a, [ `readable | `writable ]) OBus_property.t
end