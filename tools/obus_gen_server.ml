(*
 * obus_gen_server.ml
 * ------------------
 * Copyright : (c) 2010, Jeremie Dimino <jeremie@dimino.org>
 * Licence   : BSD3
 *
 * This file is a part of obus, an ocaml implementation of D-Bus.
 *)

open Printf
open OBus_introspect
open OBus_value

let prog_name = Filename.basename Sys.argv.(0)

let make_names args =
  let _, l =
    List.fold_left
      (fun (n, l) (name, typ) ->
         match name with
           | None -> (n + 1, (false, "x" ^ string_of_int n) :: l)
           | Some "type" -> (n, (true, "typ") :: l)
           | Some name -> (n, (true, name) :: l))
      (1, [])
      args
  in
  List.rev l

(* +-----------------------------------------------------------------+
   | Implementation generation                                       |
   +-----------------------------------------------------------------+ *)

let print_names oc = function
  | [] ->
      output_string oc "()";
  | [(_, name)] ->
      output_string oc name
  | (_, name) :: names ->
      output_char oc '(';
      output_string oc name;
      List.iter (fun (_, name) -> fprintf oc ", %s" name) names;
      output_char oc ')'

let rec contains_path = function
  | T.Basic T.Object_path -> true
  | T.Basic _ -> false
  | T.Array t -> contains_path t
  | T.Dict(T.Object_path, _) -> true
  | T.Dict(_, tv) -> contains_path tv
  | T.Structure tl -> List.exists contains_path tl
  | T.Variant -> false

let make_convertors make_convertor names args =
  List.map2
    (fun (_, name) (_, typ) -> match make_convertor typ with
       | Some f -> Some(sprintf "let %s = %s %s in\n" name f name)
       | None -> None)
    names args

let print_impl oc name members annotations =
  let module_name = String.capitalize (Utils.file_name_of_interface_name name) in
  fprintf oc "\n\
              module %s =\n\
              struct\n\
             \  open %s\n"
    module_name module_name;
  List.iter
    (function
       | Signal(name, args, annotations) ->
           let names = make_names args in
           let convertors = make_convertors Utils.convertor_send names args in
           fprintf oc "\n  let %s obj" (OBus_name.ocaml_lid name);
           List.iter
             (function
                | (false, name) -> fprintf oc " %s" name
                | (true, name) -> fprintf oc " ~%s" name)
             names;
           output_string oc " =\n";
           List.iter
             (function
                | Some line -> fprintf oc "    %s" line
                | None -> ())
             convertors;
           fprintf oc "    OBus_signal.emit s_%s obj" name;
           List.iter
             (fun (_, name) -> fprintf oc " %s" name)
             names;
           output_char oc '\n'
       | _ ->
           ())
    members;
  List.iter
    (function
       | Method(name, i_args, o_args, annotations) ->
           fprintf oc "\n  let %s obj" (OBus_name.ocaml_lid name);
           List.iter
             (function
                | (false, name) -> fprintf oc " %s" name
                | (true, name) -> fprintf oc " ~%s" name)
             (make_names i_args);
           output_string oc " =\n    fail (Failure \"not implemented\")\n"
       | _ ->
           ())
    members;
  fprintf oc "\n  let interface =\n\
               \    %s.make\n" module_name;
  List.iter
    (function
       | Method(name, i_args, o_args, annotations) ->
           let i_names = make_names i_args and o_names = make_names o_args in
           let i_convertors = make_convertors Utils.convertor_recv i_names i_args
           and o_convertors = make_convertors Utils.convertor_send o_names o_args in
           fprintf oc "      ~m_%s:(fun ctx obj %a" name print_names i_names;
           if List.for_all (fun x -> x = None) i_convertors && List.for_all (fun x -> x = None) i_convertors then begin
             fprintf oc " -> %s obj" (OBus_name.ocaml_lid name);
             List.iter (fun (_, name) -> fprintf oc " %s" name) i_names;
             output_string oc ")\n"
           end else begin
             let padding = String.make (13 + String.length name) ' ' in
             output_string oc " ->\n";
             List.iter
               (function
                  | Some line -> fprintf oc "%s%s" padding line
                  | None -> ())
               i_convertors;
             if List.for_all (fun x -> x = None) o_convertors then begin
               fprintf oc "%s%s obj" padding (OBus_name.ocaml_lid name);
               List.iter (fun (_, name) -> fprintf oc " %s" name) i_names;
               output_string oc ")\n"
             end else begin
               fprintf oc "%slwt %a = %s obj" padding print_names o_names (OBus_name.ocaml_lid name);
               List.iter (fun (_, name) -> fprintf oc " %s" name) i_names;
               output_string oc " in\n";
               List.iter
                 (function
                    | Some line -> fprintf oc "%s%s" padding line
                    | None -> ())
                 o_convertors;
               fprintf oc "%sreturn %a)\n" padding print_names o_names
             end
           end
       | Property(name, typ, access, annotations) ->
           fprintf oc "      ~p_%s:" name;
           if access = Read_write then output_char oc '(';
           if access = Read || access = Read_write then
             output_string oc "(fun obj -> failwith \"not implemented\")";
           if access = Read_write then begin
             output_string oc ",\n";
             output_string oc (String.make (11 + String.length name) ' ')
           end;
           if access = Write || access = Read_write then
             output_string oc "(fun ctx obj x -> failwith \"not implemented\")";
           if access = Read_write then
             output_char oc ')';
           output_char oc '\n'
       | _ ->
           ())
    members;
  output_string oc "      ()\n";
  output_string oc "end\n"

(* +-----------------------------------------------------------------+
   | Entry-point                                                     |
   +-----------------------------------------------------------------+ *)

let usage_message =
  Printf.sprintf "Usage: %s <options> <files>\n\
                  Generate OCaml server code for D-Bus interfaces.\n\
                  options are:"
    prog_name

let keep_common = ref false
let prefix = ref "obus_server"

let args = [
  "-keep-common", Arg.Set keep_common, "do not ignore common interfaces";
  "-o", Arg.Set_string prefix, "<prefix> output file prefix";
]

let () =
  let sources = ref [] in
  Arg.parse args (fun s -> sources := s :: !sources) usage_message;

  if !sources = [] then begin
    Arg.usage args usage_message;
    exit 1
  end;

  (* Parse source files *)
  let interfaces =
    List.fold_left
      (fun acc file_name ->
         Utils.IFSet.union acc (Utils.parse_file file_name))
      Utils.IFSet.empty
      !sources
  in

  let oc = open_out (!prefix ^ ".ml") in

  output_string oc "open Lwt\n";

  Utils.IFSet.iter
    (fun (name, members, annotations) ->
       if !keep_common ||
         (match OBus_name.split name with
            | "org" :: "freedesktop" :: "DBus" :: _ -> false
            | _ -> true) then begin
           print_impl oc name members annotations
         end)
    interfaces;

  close_out oc;

  printf "file \"%s.ml\" written\n" !prefix
