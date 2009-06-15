(* camlp5r pa_macro.cmo *)
(***********************************************************************)
(*                                                                     *)
(*                             Camlp5                                  *)
(*                                                                     *)
(*                Daniel de Rauglaudre, INRIA Rocquencourt             *)
(*                                                                     *)
(*  Copyright 2007 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

(* $Id: mLast.mli,v 1.22 2007/09/09 11:26:09 deraugla Exp $ *)

(* Module [MLast]: abstract syntax tree.

   This is undocumented because the AST is not supposed to be used
   directly; the good usage is to use the quotations representing
   these values in concrete syntax (see the Camlp5 documentation).
   See also the file q_MLast.ml in Camlp5 sources. *)

type loc = Ploc.t;

IFNDEF STRICT THEN
  DEFINE V t = t
ELSE
  DEFINE V t = Ploc.vala t
END;

type ctyp =
  [ TyAcc of loc and ctyp and ctyp
  | TyAli of loc and ctyp and ctyp
  | TyAny of loc
  | TyApp of loc and ctyp and ctyp
  | TyArr of loc and ctyp and ctyp
  | TyCls of loc and list string
  | TyLab of loc and string and ctyp
  | TyLid of loc and V string
  | TyMan of loc and ctyp and ctyp
  | TyObj of loc and list (string * ctyp) and bool
  | TyOlb of loc and string and ctyp
  | TyPol of loc and list string and ctyp
  | TyQuo of loc and V string
  | TyRec of loc and list (loc * string * bool * ctyp)
  | TySum of loc and list (loc * string * list ctyp)
  | TyTup of loc and list ctyp
  | TyUid of loc and string
  | TyVrn of loc and list poly_variant and option (option (list string))
  | IFDEF STRICT THEN
      TyXtr of loc and string and option ctyp
    END ]
and poly_variant =
  [ PvTag of string and bool and list ctyp
  | PvInh of ctyp ]
;

type type_var = (string * (bool * bool));

type class_infos 'a =
  { ciLoc : loc;
    ciVir : bool;
    ciPrm : (loc * list type_var);
    ciNam : string;
    ciExp : 'a }
;

type patt =
  [ PaAcc of loc and patt and patt
  | PaAli of loc and patt and patt
  | PaAnt of loc and patt
  | PaAny of loc
  | PaApp of loc and patt and patt
  | PaArr of loc and list patt
  | PaChr of loc and string
  | PaInt of loc and string and string
  | PaFlo of loc and string
  | PaLab of loc and string and option patt
  | PaLid of loc and V string
  | PaOlb of loc and string and option (patt * option expr)
  | PaOrp of loc and patt and patt
  | PaRng of loc and patt and patt
  | PaRec of loc and list (patt * patt)
  | PaStr of loc and string
  | PaTup of loc and V (list patt)
  | PaTyc of loc and patt and ctyp
  | PaTyp of loc and list string
  | PaUid of loc and string
  | PaVrn of loc and string
  | IFDEF STRICT THEN
      PaXtr of loc and string and option patt
    END ]
and expr =
  [ ExAcc of loc and expr and expr
  | ExAnt of loc and expr
  | ExApp of loc and expr and expr
  | ExAre of loc and expr and expr
  | ExArr of loc and list expr
  | ExAsr of loc and expr
  | ExAss of loc and expr and expr
  | ExBae of loc and expr and list expr
  | ExChr of loc and string
  | ExCoe of loc and expr and option ctyp and ctyp
  | ExFlo of loc and string
  | ExFor of loc and string and expr and expr and bool and list expr
  | ExFun of loc and list (patt * option expr * expr)
  | ExIfe of loc and expr and expr and expr
  | ExInt of loc and string and string
  | ExLab of loc and string and option expr
  | ExLaz of loc and expr
  | ExLet of loc and V bool and V (list (patt * expr)) and expr
  | ExLid of loc and V string
  | ExLmd of loc and string and module_expr and expr
  | ExMat of loc and expr and list (patt * option expr * expr)
  | ExNew of loc and list string
  | ExObj of loc and option patt and list class_str_item
  | ExOlb of loc and string and option expr
  | ExOvr of loc and list (string * expr)
  | ExRec of loc and V (list (patt * expr)) and option expr
  | ExSeq of loc and list expr
  | ExSnd of loc and expr and string
  | ExSte of loc and expr and expr
  | ExStr of loc and V string
  | ExTry of loc and expr and list (patt * option expr * expr)
  | ExTup of loc and V (list expr)
  | ExTyc of loc and expr and ctyp
  | ExUid of loc and V string
  | ExVrn of loc and string
  | ExWhi of loc and expr and list expr
  | IFDEF STRICT THEN
      ExXtr of loc and string and option expr
    END ]
and module_type =
  [ MtAcc of loc and module_type and module_type
  | MtApp of loc and module_type and module_type
  | MtFun of loc and string and module_type and module_type
  | MtLid of loc and string
  | MtQuo of loc and string
  | MtSig of loc and list sig_item
  | MtUid of loc and string
  | MtWit of loc and module_type and list with_constr ]
and sig_item =
  [ SgCls of loc and list (class_infos class_type)
  | SgClt of loc and list (class_infos class_type)
  | SgDcl of loc and list sig_item
  | SgDir of loc and string and option expr
  | SgExc of loc and string and list ctyp
  | SgExt of loc and string and ctyp and list string
  | SgInc of loc and module_type
  | SgMod of loc and bool and list (string * module_type)
  | SgMty of loc and string and module_type
  | SgOpn of loc and list string
  | SgTyp of loc and list type_decl
  | SgUse of loc and string and list (sig_item * loc)
  | SgVal of loc and string and ctyp ]
and with_constr =
  [ WcTyp of loc and list string and list type_var and bool and ctyp
  | WcMod of loc and list string and module_expr ]
and module_expr =
  [ MeAcc of loc and module_expr and module_expr
  | MeApp of loc and module_expr and module_expr
  | MeFun of loc and string and module_type and module_expr
  | MeStr of loc and list str_item
  | MeTyc of loc and module_expr and module_type
  | MeUid of loc and string ]
and str_item =
  [ StCls of loc and list (class_infos class_expr)
  | StClt of loc and list (class_infos class_type)
  | StDcl of loc and list str_item
  | StDir of loc and string and option expr
  | StExc of loc and string and list ctyp and list string
  | StExp of loc and expr
  | StExt of loc and string and ctyp and list string
  | StInc of loc and module_expr
  | StMod of loc and bool and list (string * module_expr)
  | StMty of loc and string and module_type
  | StOpn of loc and list string
  | StTyp of loc and list type_decl
  | StUse of loc and string and list (str_item * loc)
  | StVal of loc and V bool and list (patt * expr) ]
and type_decl =
  { tdNam : (loc * string);
    tdPrm : list type_var;
    tdPrv : bool;
    tdDef : ctyp;
    tdCon : list (ctyp * ctyp) }
and class_type =
  [ CtCon of loc and list string and list ctyp
  | CtFun of loc and ctyp and class_type
  | CtSig of loc and option ctyp and list class_sig_item ]
and class_sig_item =
  [ CgCtr of loc and ctyp and ctyp
  | CgDcl of loc and list class_sig_item
  | CgInh of loc and class_type
  | CgMth of loc and string and bool and ctyp
  | CgVal of loc and string and bool and ctyp
  | CgVir of loc and string and bool and ctyp ]
and class_expr =
  [ CeApp of loc and class_expr and expr
  | CeCon of loc and list string and list ctyp
  | CeFun of loc and patt and class_expr
  | CeLet of loc and bool and list (patt * expr) and class_expr
  | CeStr of loc and option patt and list class_str_item
  | CeTyc of loc and class_expr and class_type ]
and class_str_item =
  [ CrCtr of loc and ctyp and ctyp
  | CrDcl of loc and list class_str_item
  | CrInh of loc and class_expr and option string
  | CrIni of loc and expr
  | CrMth of loc and string and bool and expr and option ctyp
  | CrVal of loc and string and bool and expr
  | CrVir of loc and string and bool and ctyp ]
;

external loc_of_ctyp : ctyp -> loc = "%field0";
external loc_of_patt : patt -> loc = "%field0";
external loc_of_expr : expr -> loc = "%field0";
external loc_of_module_type : module_type -> loc = "%field0";
external loc_of_module_expr : module_expr -> loc = "%field0";
external loc_of_sig_item : sig_item -> loc = "%field0";
external loc_of_str_item : str_item -> loc = "%field0";

external loc_of_class_type : class_type -> loc = "%field0";
external loc_of_class_sig_item : class_sig_item -> loc = "%field0";
external loc_of_class_expr : class_expr -> loc = "%field0";
external loc_of_class_str_item : class_str_item -> loc = "%field0";
