(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*    Thomas Gazagnaire (OCamlPro), Fabrice Le Fessant (INRIA Saclay)     *)
(*                                                                        *)
(*   Copyright 2007 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(*
TODO:
 - 2012/05/10: Follow camlp4 way of building map and iter using classes
     and inheritance ?
*)

open Asttypes
open Typedtree

module type IteratorArgument = sig

    val enter_structure : structure -> unit
    val enter_value_description : value_description -> unit
    val enter_type_extension : type_extension -> unit
    val enter_type_exception : type_exception -> unit
    val enter_extension_constructor : extension_constructor -> unit
    val enter_pattern : pattern -> unit
    val enter_expression : expression -> unit
    val enter_package_type : package_type -> unit
    val enter_signature : signature -> unit
    val enter_signature_item : signature_item -> unit
    val enter_module_type_declaration : module_type_declaration -> unit
    val enter_module_type : module_type -> unit
    val enter_module_expr : module_expr -> unit
    val enter_with_constraint : with_constraint -> unit
    val enter_class_expr : class_expr -> unit
    val enter_class_signature : class_signature -> unit
    val enter_class_declaration : class_declaration -> unit
    val enter_class_description : class_description -> unit
    val enter_class_type_declaration : class_type_declaration -> unit
    val enter_class_type : class_type -> unit
    val enter_class_type_field : class_type_field -> unit
    val enter_core_type : core_type -> unit
    val enter_class_structure : class_structure -> unit
    val enter_class_field : class_field -> unit
    val enter_structure_item : structure_item -> unit


    val leave_structure : structure -> unit
    val leave_value_description : value_description -> unit
    val leave_type_extension : type_extension -> unit
    val leave_type_exception : type_exception -> unit
    val leave_extension_constructor : extension_constructor -> unit
    val leave_pattern : pattern -> unit
    val leave_expression : expression -> unit
    val leave_package_type : package_type -> unit
    val leave_signature : signature -> unit
    val leave_signature_item : signature_item -> unit
    val leave_module_type_declaration : module_type_declaration -> unit
    val leave_module_type : module_type -> unit
    val leave_module_expr : module_expr -> unit
    val leave_with_constraint : with_constraint -> unit
    val leave_class_expr : class_expr -> unit
    val leave_class_signature : class_signature -> unit
    val leave_class_declaration : class_declaration -> unit
    val leave_class_description : class_description -> unit
    val leave_class_type_declaration : class_type_declaration -> unit
    val leave_class_type : class_type -> unit
    val leave_class_type_field : class_type_field -> unit
    val leave_core_type : core_type -> unit
    val leave_class_structure : class_structure -> unit
    val leave_class_field : class_field -> unit
    val leave_structure_item : structure_item -> unit

    val enter_bindings : rec_flag -> unit
    val enter_binding : value_binding -> unit
    val leave_binding : value_binding -> unit
    val leave_bindings : rec_flag -> unit

    val enter_type_declarations : rec_flag -> unit
    val enter_type_declaration : type_declaration -> unit
    val leave_type_declaration : type_declaration -> unit
    val leave_type_declarations : rec_flag -> unit

      end

module MakeIterator(Iter : IteratorArgument) : sig

    val iter_structure : structure -> unit
    val iter_signature : signature -> unit
    val iter_structure_item : structure_item -> unit
    val iter_signature_item : signature_item -> unit
    val iter_expression : expression -> unit
    val iter_module_type : module_type -> unit
    val iter_pattern : pattern -> unit
    val iter_class_expr : class_expr -> unit

  end = struct

    let may_iter f v =
      match v with
        None -> ()
      | Some x -> f x


    let rec iter_structure str =
      Iter.enter_structure str;
      List.iter iter_structure_item str.str_items;
      Iter.leave_structure str


    and iter_binding vb =
      Iter.enter_binding vb;
      iter_pattern vb.vb_pat;
      iter_expression vb.vb_expr;
      Iter.leave_binding vb

    and iter_bindings rec_flag list =
      Iter.enter_bindings rec_flag;
      List.iter iter_binding list;
      Iter.leave_bindings rec_flag

    and iter_case {c_lhs; c_guard; c_rhs} =
      iter_pattern c_lhs;
      may_iter iter_expression c_guard;
      iter_expression c_rhs

    and iter_cases cases =
      List.iter iter_case cases

    and iter_structure_item item =
      Iter.enter_structure_item item;
      begin
        match item.str_desc with
          Tstr_eval (exp, _attrs) -> iter_expression exp
        | Tstr_value (rec_flag, list) ->
            iter_bindings rec_flag list
        | Tstr_primitive vd -> iter_value_description vd
        | Tstr_type (rf, list) -> iter_type_declarations rf list
        | Tstr_typext tyext -> iter_type_extension tyext
        | Tstr_exception ext -> iter_type_exception ext
        | Tstr_module x -> iter_module_binding x
        | Tstr_recmodule list -> List.iter iter_module_binding list
        | Tstr_modtype mtd -> iter_module_type_declaration mtd
        | Tstr_open od -> iter_module_expr od.open_expr
        | Tstr_class list ->
            List.iter (fun (ci, _) -> iter_class_declaration ci) list
        | Tstr_class_type list ->
            List.iter
              (fun (_, _, ct) -> iter_class_type_declaration ct)
              list
        | Tstr_include incl -> iter_module_expr incl.incl_mod
        | Tstr_attribute _ ->
            ()
      end;
      Iter.leave_structure_item item

    and iter_module_binding x =
      iter_module_expr x.mb_expr

    and iter_value_description v =
      Iter.enter_value_description v;
      iter_core_type v.val_desc;
      Iter.leave_value_description v

    and iter_constructor_arguments = function
      | Cstr_tuple l -> List.iter iter_core_type l
      | Cstr_record l -> List.iter (fun ld -> iter_core_type ld.ld_type) l

    and iter_constructor_declaration cd =
      iter_constructor_arguments cd.cd_args;
      option iter_core_type cd.cd_res;

    and iter_type_parameter (ct, _v) =
      iter_core_type ct

    and iter_type_declaration decl =
      Iter.enter_type_declaration decl;
      List.iter iter_type_parameter decl.typ_params;
      List.iter (fun (ct1, ct2, _loc) ->
          iter_core_type ct1;
          iter_core_type ct2
      ) decl.typ_cstrs;
      begin match decl.typ_kind with
          Ttype_abstract -> ()
        | Ttype_variant list ->
            List.iter iter_constructor_declaration list
        | Ttype_record list ->
            List.iter
              (fun ld ->
                iter_core_type ld.ld_type
            ) list
        | Ttype_open -> ()
      end;
      option iter_core_type decl.typ_manifest;
      Iter.leave_type_declaration decl

    and iter_type_declarations rec_flag decls =
      Iter.enter_type_declarations rec_flag;
      List.iter iter_type_declaration decls;
      Iter.leave_type_declarations rec_flag

    and iter_extension_constructor ext =
      Iter.enter_extension_constructor ext;
      begin match ext.ext_kind with
          Text_decl(args, ret) ->
          iter_constructor_arguments args;
            option iter_core_type ret
        | Text_rebind _ -> ()
      end;
      Iter.leave_extension_constructor ext;

    and iter_type_extension (tyext: type_extension) : unit =
      Iter.enter_type_extension tyext;
      List.iter iter_type_parameter tyext.tyext_params;
      List.iter iter_extension_constructor tyext.tyext_constructors;
      Iter.leave_type_extension tyext

    and iter_type_exception (tyexn: type_exception) =
      Iter.enter_type_exception tyexn;
      iter_extension_constructor tyexn.tyexn_constructor;
      Iter.leave_type_exception tyexn

    and iter_pattern pat =
      Iter.enter_pattern pat;
      List.iter (fun (cstr, _, _attrs) -> match cstr with
              | Tpat_type _ -> ()
              | Tpat_unpack -> ()
              | Tpat_open _ -> ()
              | Tpat_constraint ct -> iter_core_type ct) pat.pat_extra;
      begin
        match pat.pat_desc with
          Tpat_any -> ()
        | Tpat_var _ -> ()
        | Tpat_alias (pat1, _, _) -> iter_pattern pat1
        | Tpat_constant _ -> ()
        | Tpat_tuple list ->
            List.iter iter_pattern list
        | Tpat_construct (_, _, args) ->
            List.iter iter_pattern args
        | Tpat_variant (_, pato, _) ->
            begin match pato with
                None -> ()
              | Some pat -> iter_pattern pat
            end
        | Tpat_record (list, _closed) ->
            List.iter (fun (_, _, pat) -> iter_pattern pat) list
        | Tpat_array list -> List.iter iter_pattern list
        | Tpat_or (p1, p2, _) -> iter_pattern p1; iter_pattern p2
        | Tpat_lazy p
        | Tpat_exception p -> iter_pattern p
      end;
      Iter.leave_pattern pat

    and option f x = match x with None -> () | Some e -> f e

    and iter_expression exp =
      Iter.enter_expression exp;
      List.iter (function (cstr, _, _attrs) ->
        match cstr with
          Texp_constraint ct ->
            iter_core_type ct
        | Texp_coerce (cty1, cty2) ->
            option iter_core_type cty1; iter_core_type cty2
        | Texp_poly cto -> option iter_core_type cto
        | Texp_newtype _ -> ())
        exp.exp_extra;
      begin
        match exp.exp_desc with
          Texp_ident _ -> ()
        | Texp_constant _ -> ()
        | Texp_let (rec_flag, list, exp) ->
            iter_bindings rec_flag list;
            iter_expression exp
        | Texp_function { cases; _ } ->
            iter_cases cases
        | Texp_apply (exp, list) ->
            iter_expression exp;
            List.iter (fun (_label, expo) ->
                match expo with
                  None -> ()
                | Some exp -> iter_expression exp
            ) list
        | Texp_match (exp, list, _) ->
            iter_expression exp;
            iter_cases list
        | Texp_try (exp, list) ->
            iter_expression exp;
            iter_cases list
        | Texp_tuple list ->
            List.iter iter_expression list
        | Texp_construct (_, _, args) ->
            List.iter iter_expression args
        | Texp_variant (_label, expo) ->
            begin match expo with
                None -> ()
              | Some exp -> iter_expression exp
            end
        | Texp_record { fields; extended_expression; _ } ->
            Array.iter (function
                | _, Kept _ -> ()
                | _, Overridden (_, exp) -> iter_expression exp)
              fields;
            begin match extended_expression with
                None -> ()
              | Some exp -> iter_expression exp
            end
        | Texp_field (exp, _, _label) ->
            iter_expression exp
        | Texp_setfield (exp1, _, _label, exp2) ->
            iter_expression exp1;
            iter_expression exp2
        | Texp_array list ->
            List.iter iter_expression list
        | Texp_ifthenelse (exp1, exp2, expo) ->
            iter_expression exp1;
            iter_expression exp2;
            begin match expo with
                None -> ()
              | Some exp -> iter_expression exp
            end
        | Texp_sequence (exp1, exp2) ->
            iter_expression exp1;
            iter_expression exp2
        | Texp_while (exp1, exp2) ->
            iter_expression exp1;
            iter_expression exp2
        | Texp_for (_id, _, exp1, exp2, _dir, exp3) ->
            iter_expression exp1;
            iter_expression exp2;
            iter_expression exp3
        | Texp_send (exp, _meth, expo) ->
            iter_expression exp;
          begin
            match expo with
                None -> ()
              | Some exp -> iter_expression exp
          end
        | Texp_new _ -> ()
        | Texp_instvar _ -> ()
        | Texp_setinstvar (_, _, _, exp) ->
            iter_expression exp
        | Texp_override (_, list) ->
            List.iter (fun (_path, _, exp) ->
                iter_expression exp
            ) list
        | Texp_letmodule (_id, _, _, mexpr, exp) ->
            iter_module_expr mexpr;
            iter_expression exp
        | Texp_letexception (cd, exp) ->
            iter_extension_constructor cd;
            iter_expression exp
        | Texp_assert exp -> iter_expression exp
        | Texp_lazy exp -> iter_expression exp
        | Texp_object (cl, _) ->
            iter_class_structure cl
        | Texp_pack (mexpr) ->
            iter_module_expr mexpr
        | Texp_letop{let_; ands; param = _; body; partial = _} ->
            iter_binding_op let_;
            List.iter iter_binding_op ands;
            iter_case body
        | Texp_unreachable ->
            ()
        | Texp_extension_constructor _ ->
            ()
        | Texp_open (od, e) ->
            iter_module_expr od.open_expr;
            iter_expression e
      end;
      Iter.leave_expression exp;

    and iter_binding_op bop =
      iter_expression bop.bop_exp

    and iter_package_type pack =
      Iter.enter_package_type pack;
      List.iter (fun (_s, ct) -> iter_core_type ct) pack.pack_fields;
      Iter.leave_package_type pack;

    and iter_signature sg =
      Iter.enter_signature sg;
      List.iter iter_signature_item sg.sig_items;
      Iter.leave_signature sg;

    and iter_signature_item item =
      Iter.enter_signature_item item;
      begin
        match item.sig_desc with
          Tsig_value vd ->
            iter_value_description vd
        | Tsig_type (rf, list) ->
            iter_type_declarations rf list
        | Tsig_typesubst list ->
            iter_type_declarations Nonrecursive list
        | Tsig_exception ext ->
            iter_type_exception ext
        | Tsig_typext tyext ->
            iter_type_extension tyext
        | Tsig_module md ->
            iter_module_type md.md_type
        | Tsig_modsubst _ -> ()
        | Tsig_recmodule list ->
            List.iter (fun md -> iter_module_type md.md_type) list
        | Tsig_modtype mtd ->
            iter_module_type_declaration mtd
        | Tsig_open _ -> ()
        | Tsig_include incl -> iter_module_type incl.incl_mod
        | Tsig_class list ->
            List.iter iter_class_description list
        | Tsig_class_type list ->
            List.iter iter_class_type_declaration list
        | Tsig_attribute _ -> ()
      end;
      Iter.leave_signature_item item;

    and iter_module_type_declaration mtd =
      Iter.enter_module_type_declaration mtd;
      begin
        match mtd.mtd_type with
        | None -> ()
        | Some mtype -> iter_module_type mtype
      end;
      Iter.leave_module_type_declaration mtd

    and iter_class_declaration cd =
      Iter.enter_class_declaration cd;
      List.iter iter_type_parameter cd.ci_params;
      iter_class_expr cd.ci_expr;
      Iter.leave_class_declaration cd;

    and iter_class_description cd =
      Iter.enter_class_description cd;
      List.iter iter_type_parameter cd.ci_params;
      iter_class_type cd.ci_expr;
      Iter.leave_class_description cd;

    and iter_class_type_declaration cd =
      Iter.enter_class_type_declaration cd;
      List.iter iter_type_parameter cd.ci_params;
      iter_class_type cd.ci_expr;
      Iter.leave_class_type_declaration cd;

    and iter_module_type mty =
      Iter.enter_module_type mty;
      begin
        match mty.mty_desc with
          Tmty_ident _ -> ()
        | Tmty_alias _ -> ()
        | Tmty_signature sg -> iter_signature sg
        | Tmty_functor (Unit, mtype2) ->
            iter_module_type mtype2
        | Tmty_functor (Named (_, _, mtype1), mtype2) ->
            iter_module_type mtype1; iter_module_type mtype2
        | Tmty_with (mtype, list) ->
            iter_module_type mtype;
            List.iter (fun (_path, _, withc) ->
                iter_with_constraint withc
            ) list
        | Tmty_typeof mexpr ->
            iter_module_expr mexpr
      end;
      Iter.leave_module_type mty;

    and iter_with_constraint cstr =
      Iter.enter_with_constraint cstr;
      begin
        match cstr with
          Twith_type decl -> iter_type_declaration decl
        | Twith_module _ -> ()
        | Twith_typesubst decl -> iter_type_declaration decl
        | Twith_modsubst _ -> ()
      end;
      Iter.leave_with_constraint cstr;

    and iter_module_expr mexpr =
      Iter.enter_module_expr mexpr;
      begin
        match mexpr.mod_desc with
          Tmod_ident _ -> ()
        | Tmod_structure st -> iter_structure st
        | Tmod_functor (Unit, mexpr) ->
            iter_module_expr mexpr
        | Tmod_functor (Named (_, _, mtype), mexpr) ->
            iter_module_type mtype;
            iter_module_expr mexpr
        | Tmod_apply (mexp1, mexp2, _) ->
            iter_module_expr mexp1;
            iter_module_expr mexp2
        | Tmod_constraint (mexpr, _, Tmodtype_implicit, _ ) ->
            iter_module_expr mexpr
        | Tmod_constraint (mexpr, _, Tmodtype_explicit mtype, _) ->
            iter_module_expr mexpr;
            iter_module_type mtype
        | Tmod_unpack (exp, _mty) ->
            iter_expression exp
(*          iter_module_type mty *)
      end;
      Iter.leave_module_expr mexpr;

    and iter_class_expr cexpr =
      Iter.enter_class_expr cexpr;
      begin
        match cexpr.cl_desc with
        | Tcl_constraint (cl, None, _, _, _ ) ->
            iter_class_expr cl;
        | Tcl_structure clstr -> iter_class_structure clstr
        | Tcl_fun (_label, pat, priv, cl, _partial) ->
          iter_pattern pat;
          List.iter (fun (_id, exp) -> iter_expression exp) priv;
          iter_class_expr cl

        | Tcl_apply (cl, args) ->
            iter_class_expr cl;
            List.iter (fun (_label, expo) ->
                match expo with
                  None -> ()
                | Some exp -> iter_expression exp
            ) args

        | Tcl_let (rec_flat, bindings, ivars, cl) ->
          iter_bindings rec_flat bindings;
          List.iter (fun (_id, exp) -> iter_expression exp) ivars;
            iter_class_expr cl

        | Tcl_constraint (cl, Some clty, _vals, _meths, _concrs) ->
            iter_class_expr cl;
            iter_class_type clty

        | Tcl_ident (_, _, tyl) ->
            List.iter iter_core_type tyl

        | Tcl_open (_, e) ->
            iter_class_expr e
      end;
      Iter.leave_class_expr cexpr;

    and iter_class_type ct =
      Iter.enter_class_type ct;
      begin
        match ct.cltyp_desc with
          Tcty_signature csg -> iter_class_signature csg
        | Tcty_constr (_path, _, list) ->
            List.iter iter_core_type list
        | Tcty_arrow (_label, ct, cl) ->
            iter_core_type ct;
            iter_class_type cl
        | Tcty_open (_, e) ->
            iter_class_type e
      end;
      Iter.leave_class_type ct;

    and iter_class_signature cs =
      Iter.enter_class_signature cs;
      iter_core_type cs.csig_self;
      List.iter iter_class_type_field cs.csig_fields;
      Iter.leave_class_signature cs


    and iter_class_type_field ctf =
      Iter.enter_class_type_field ctf;
      begin
        match ctf.ctf_desc with
          Tctf_inherit ct -> iter_class_type ct
        | Tctf_val (_s, _mut, _virt, ct) ->
            iter_core_type ct
        | Tctf_method (_s, _priv, _virt, ct) ->
            iter_core_type ct
        | Tctf_constraint  (ct1, ct2) ->
            iter_core_type ct1;
            iter_core_type ct2
        | Tctf_attribute _ -> ()
      end;
      Iter.leave_class_type_field ctf

    and iter_core_type ct =
      Iter.enter_core_type ct;
      begin
        match ct.ctyp_desc with
          Ttyp_any -> ()
        | Ttyp_var _ -> ()
        | Ttyp_arrow (_label, ct1, ct2) ->
            iter_core_type ct1;
            iter_core_type ct2
        | Ttyp_tuple list -> List.iter iter_core_type list
        | Ttyp_constr (_path, _, list) ->
            List.iter iter_core_type list
        | Ttyp_object (list, _o) ->
            List.iter iter_object_field list
        | Ttyp_class (_path, _, list) ->
            List.iter iter_core_type list
        | Ttyp_alias (ct, _s) ->
            iter_core_type ct
        | Ttyp_variant (list, _bool, _labels) ->
            List.iter iter_row_field list
        | Ttyp_poly (_list, ct) -> iter_core_type ct
        | Ttyp_package pack -> iter_package_type pack
      end;
      Iter.leave_core_type ct

    and iter_class_structure cs =
      Iter.enter_class_structure cs;
      iter_pattern cs.cstr_self;
      List.iter iter_class_field cs.cstr_fields;
      Iter.leave_class_structure cs;


    and iter_row_field rf =
      match rf.rf_desc with
      | Ttag (_label, _bool, list) ->
          List.iter iter_core_type list
      | Tinherit ct -> iter_core_type ct

    and iter_object_field ofield =
      match ofield.of_desc with
      | OTtag (_, ct) | OTinherit ct -> iter_core_type ct

    and iter_class_field cf =
      Iter.enter_class_field cf;
      begin
        match cf.cf_desc with
          Tcf_inherit (_ovf, cl, _super, _vals, _meths) ->
          iter_class_expr cl
      | Tcf_constraint (cty, cty') ->
          iter_core_type cty;
          iter_core_type cty'
      | Tcf_val (_lab, _, _, Tcfk_virtual cty, _) ->
          iter_core_type cty
      | Tcf_val (_lab, _, _, Tcfk_concrete (_, exp), _) ->
          iter_expression exp
      | Tcf_method (_lab, _, Tcfk_virtual cty) ->
          iter_core_type cty
      | Tcf_method (_lab, _, Tcfk_concrete (_, exp)) ->
          iter_expression exp
      | Tcf_initializer exp ->
          iter_expression exp
      | Tcf_attribute _ -> ()
      end;
      Iter.leave_class_field cf;
  end

module DefaultIteratorArgument = struct

      let enter_structure _ = ()
      let enter_value_description _ = ()
      let enter_type_extension _ = ()
      let enter_type_exception _ = ()
      let enter_extension_constructor _ = ()
      let enter_pattern _ = ()
      let enter_expression _ = ()
      let enter_package_type _ = ()
      let enter_signature _ = ()
      let enter_signature_item _ = ()
      let enter_module_type_declaration _ = ()
      let enter_module_type _ = ()
      let enter_module_expr _ = ()
      let enter_with_constraint _ = ()
      let enter_class_expr _ = ()
      let enter_class_signature _ = ()
      let enter_class_declaration _ = ()
      let enter_class_description _ = ()
      let enter_class_type_declaration _ = ()
      let enter_class_type _ = ()
      let enter_class_type_field _ = ()
      let enter_core_type _ = ()
      let enter_class_structure _ = ()
    let enter_class_field _ = ()
    let enter_structure_item _ = ()


      let leave_structure _ = ()
      let leave_value_description _ = ()
      let leave_type_extension _ = ()
      let leave_type_exception _ = ()
      let leave_extension_constructor _ = ()
      let leave_pattern _ = ()
      let leave_expression _ = ()
      let leave_package_type _ = ()
      let leave_signature _ = ()
      let leave_signature_item _ = ()
      let leave_module_type_declaration _ = ()
      let leave_module_type _ = ()
      let leave_module_expr _ = ()
      let leave_with_constraint _ = ()
      let leave_class_expr _ = ()
      let leave_class_signature _ = ()
      let leave_class_declaration _ = ()
      let leave_class_description _ = ()
      let leave_class_type_declaration _ = ()
      let leave_class_type _ = ()
      let leave_class_type_field _ = ()
      let leave_core_type _ = ()
      let leave_class_structure _ = ()
    let leave_class_field _ = ()
    let leave_structure_item _ = ()

    let enter_binding _ = ()
    let leave_binding _ = ()

    let enter_bindings _ = ()
    let leave_bindings _ = ()

    let enter_type_declaration _ = ()
    let leave_type_declaration _ = ()

    let enter_type_declarations _ = ()
    let leave_type_declarations _ = ()
end
