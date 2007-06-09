(* camlp4 pa_r.cmo pa_rp.cmo pa_extend.cmo q_MLast.cmo pr_dump.cmo *)
(* File generated by pretty print; do not edit! *)

open Pcaml;
open Stdpp;

type choice 'a 'b =
  [ Left of 'a
  | Right of 'b ]
;

(* Buffer *)

module Buff =
  struct
    value buff = ref (String.create 80);
    value store len x = do {
      if len >= String.length buff.val then
        buff.val := buff.val ^ String.create (String.length buff.val)
      else ();
      buff.val.[len] := x;
      succ len
    }
    ;
    value get len = String.sub buff.val 0 len;
  end
;

(* Lexer *)

value rec skip_to_eol =
  parser
  [ [: `'\n' | '\r' :] -> ()
  | [: `_; s :] -> skip_to_eol s ]
;

value no_ident = ['('; ')'; '['; ']'; '{'; '}'; ' '; '\t'; '\n'; '\r'; ';'];

value rec ident len =
  parser
  [ [: `'.' :] -> (Buff.get len, True)
  | [: `x when not (List.mem x no_ident); s :] -> ident (Buff.store len x) s
  | [: :] -> (Buff.get len, False) ]
;

value identifier kwt (s, dot) =
  let con =
    try do { (Hashtbl.find kwt s : unit); "" } with
    [ Not_found ->
        match s.[0] with
        [ 'A'..'Z' -> if dot then "UIDENTDOT" else "UIDENT"
        | _ -> if dot then "LIDENTDOT" else "LIDENT" ] ]
  in
  (con, s)
;

value rec string len =
  parser
  [ [: `'"' :] -> Buff.get len
  | [: `'\\'; `c; s :] -> string (Buff.store (Buff.store len '\\') c) s
  | [: `x; s :] -> string (Buff.store len x) s ]
;

value rec end_exponent_part_under len =
  parser
  [ [: `('0'..'9' as c); s :] -> end_exponent_part_under (Buff.store len c) s
  | [: :] -> ("FLOAT", Buff.get len) ]
;

value end_exponent_part len =
  parser
  [ [: `('0'..'9' as c); s :] -> end_exponent_part_under (Buff.store len c) s
  | [: :] -> raise (Stream.Error "ill-formed floating-point constant") ]
;

value exponent_part len =
  parser
  [ [: `('+' | '-' as c); s :] -> end_exponent_part (Buff.store len c) s
  | [: a = end_exponent_part len :] -> a ]
;

value rec decimal_part len =
  parser
  [ [: `('0'..'9' as c); s :] -> decimal_part (Buff.store len c) s
  | [: `'e' | 'E'; s :] -> exponent_part (Buff.store len 'E') s
  | [: :] -> ("FLOAT", Buff.get len) ]
;

value rec number len =
  parser
  [ [: `('0'..'9' as c); s :] -> number (Buff.store len c) s
  | [: `'.'; s :] -> decimal_part (Buff.store len '.') s
  | [: `'e' | 'E'; s :] -> exponent_part (Buff.store len 'E') s
  | [: :] -> ("INT", Buff.get len) ]
;

value binary = parser [: `('0'..'1' as c) :] -> c;

value octal = parser [: `('0'..'7' as c) :] -> c;

value hexa = parser [: `('0'..'9' | 'a'..'f' | 'A'..'F' as c) :] -> c;

value rec digits_under kind len =
  parser
  [ [: d = kind; s :] -> digits_under kind (Buff.store len d) s
  | [: :] -> Buff.get len ]
;

value digits kind bp len =
  parser
  [ [: d = kind; s :] -> ("INT", digits_under kind (Buff.store len d) s)
  | [: :] ep ->
      raise_with_loc (make_loc (bp, ep))
        (Failure "ill-formed integer constant") ]
;

value base_number kwt bp len =
  parser
  [ [: `'b' | 'B'; s :] -> digits binary bp (Buff.store len 'b') s
  | [: `'o' | 'O'; s :] -> digits octal bp (Buff.store len 'o') s
  | [: `'x' | 'X'; s :] -> digits hexa bp (Buff.store len 'x') s
  | [: id = ident (Buff.store 0 '#') :] -> identifier kwt id ]
;

value rec operator len =
  parser
  [ [: `'.' :] -> Buff.get (Buff.store len '.')
  | [: :] -> Buff.get len ]
;

value char_or_quote_id x =
  parser
  [ [: `''' :] -> ("CHAR", String.make 1 x)
  | [: s :] ep ->
      if List.mem x no_ident then
        Stdpp.raise_with_loc (Stdpp.make_loc (ep - 2, ep - 1))
          (Stream.Error "bad quote")
      else
        let len = Buff.store (Buff.store 0 ''') x in
        let (s, dot) = ident len s in
        (if dot then "LIDENTDOT" else "LIDENT", s) ]
;

value rec char len =
  parser
  [ [: `''' :] -> len
  | [: `x; s :] -> char (Buff.store len x) s ]
;

value quote =
  parser
  [ [: `'\\'; len = char (Buff.store 0 '\\') :] -> ("CHAR", Buff.get len)
  | [: `x; s :] -> char_or_quote_id x s ]
;

(* The system with LIDENTDOT and UIDENTDOT is not great (it would be *)
(* better to have a token DOT (actually SPACEDOT and DOT)) but it is *)
(* the only way (that I have found) to have a good behaviour in the *)
(* toplevel (not expecting tokens after a phrase). Drawbacks: 1/ to be *)
(* complete, we should have STRINGDOT, RIGHTPARENDOT, and so on 2/ the *)
(* parser rule with dot is right associative and we have to reverse *)
(* the resulting tree (using the function leftify). *)
(* This is a complicated issue: the behaviour of the OCaml toplevel *)
(* is strange, anyway. For example, even without Camlp4, The OCaml *)
(* toplevel accepts that: *)
(*     # let x = 32;; foo bar match let ) *)

value rec lexer kwt = parser [: t = lexer0 kwt; _ = no_dot :] -> t
and no_dot =
  parser
  [ [: `'.' :] ep ->
      Stdpp.raise_with_loc (Stdpp.make_loc (ep - 1, ep))
        (Stream.Error "bad dot")
  | [: :] -> () ]
and lexer0 kwt =
  parser bp
  [ [: `'\t' | '\n' | '\r'; s :] -> lexer0 kwt s
  | [: `' '; s :] -> after_space kwt s
  | [: `';'; _ = skip_to_eol; s :] -> lexer kwt s
  | [: `'(' :] -> (("", "("), (bp, bp + 1))
  | [: `')'; s :] ep -> (("", rparen s), (bp, ep))
  | [: `'[' :] -> (("", "["), (bp, bp + 1))
  | [: `']' :] -> (("", "]"), (bp, bp + 1))
  | [: `'{' :] -> (("", "{"), (bp, bp + 1))
  | [: `'}' :] -> (("", "}"), (bp, bp + 1))
  | [: `'"'; s = string 0 :] ep -> (("STRING", s), (bp, ep))
  | [: `'''; tok = quote :] ep -> (tok, (bp, ep))
  | [: `'<'; tok = less kwt :] ep -> (tok, (bp, ep))
  | [: `'-'; tok = minus kwt :] ep -> (tok, (bp, ep))
  | [: `'~'; tok = tilde :] ep -> (tok, (bp, ep))
  | [: `'?'; tok = question :] ep -> (tok, (bp, ep))
  | [: `'#'; tok = base_number kwt bp (Buff.store 0 '0') :] ep ->
      (tok, (bp, ep))
  | [: `('0'..'9' as c); tok = number (Buff.store 0 c) :] ep ->
      (tok, (bp, ep))
  | [: `('+' | '*' | '/' as c); id = operator (Buff.store 0 c) :] ep ->
      (identifier kwt (id, False), (bp, ep))
  | [: `x; id = ident (Buff.store 0 x) :] ep -> (identifier kwt id, (bp, ep))
  | [: :] -> (("EOI", ""), (bp, bp + 1)) ]
and rparen =
  parser
  [ [: `'.' :] -> ")."
  | [: ___ :] -> ")" ]
and after_space kwt =
  parser
  [ [: `'.' :] ep -> (("", "."), (ep - 1, ep))
  | [: x = lexer0 kwt :] -> x ]
and tilde =
  parser
  [ [: `('a'..'z' as c); (s, dot) = ident (Buff.store 0 c) :] ->
      ("TILDEIDENT", s)
  | [: :] -> ("LIDENT", "~") ]
and question =
  parser
  [ [: `('a'..'z' as c); (s, dot) = ident (Buff.store 0 c) :] ->
      ("QUESTIONIDENT", s)
  | [: :] -> ("LIDENT", "?") ]
and minus kwt =
  parser
  [ [: `'.' :] -> identifier kwt ("-.", False)
  | [: `('0'..'9' as c); n = number (Buff.store (Buff.store 0 '-') c) :] -> n
  | [: id = ident (Buff.store 0 '-') :] -> identifier kwt id ]
and less kwt =
  parser
  [ [: `':'; lab = label 0; `'<' ? "'<' expected"; q = quotation 0 :] ->
      ("QUOT", lab ^ ":" ^ q)
  | [: id = ident (Buff.store 0 '<') :] -> identifier kwt id ]
and label len =
  parser
  [ [: `('a'..'z' | 'A'..'Z' | '_' as c); s :] -> label (Buff.store len c) s
  | [: :] -> Buff.get len ]
and quotation len =
  parser
  [ [: `'>'; s :] -> quotation_greater len s
  | [: `x; s :] -> quotation (Buff.store len x) s
  | [: :] -> failwith "quotation not terminated" ]
and quotation_greater len =
  parser
  [ [: `'>' :] -> Buff.get len
  | [: a = quotation (Buff.store len '>') :] -> a ]
;

value lexer_using kwt (con, prm) =
  match con with
  [ "CHAR" | "EOI" | "INT" | "FLOAT" | "LIDENT" | "LIDENTDOT" |
    "QUESTIONIDENT" | "QUOT" | "STRING" | "TILDEIDENT" | "UIDENT" |
    "UIDENTDOT" ->
      ()
  | "ANTIQUOT" -> ()
  | "" ->
      try Hashtbl.find kwt prm with [ Not_found -> Hashtbl.add kwt prm () ]
  | _ ->
      raise
        (Token.Error
           ("the constructor \"" ^ con ^ "\" is not recognized by Plexer")) ]
;

value lexer_text (con, prm) =
  if con = "" then "'" ^ prm ^ "'"
  else if prm = "" then con
  else con ^ " \"" ^ prm ^ "\""
;

value lexer_gmake () =
  let kwt = Hashtbl.create 89
  and lexer2 kwt (s, _, _) =
    let (t, loc) = lexer kwt s in
    (t, Stdpp.make_loc loc)
  in
  {Token.tok_func = Token.lexer_func_of_parser (lexer2 kwt);
   Token.tok_using = lexer_using kwt; Token.tok_removing = fun [];
   Token.tok_match = Token.default_match; Token.tok_text = lexer_text;
   Token.tok_comm = None}
;

(* Building AST *)

type sexpr =
  [ Sacc of MLast.loc and sexpr and sexpr
  | Schar of MLast.loc and string
  | Sexpr of MLast.loc and list sexpr
  | Sint of MLast.loc and string
  | Sfloat of MLast.loc and string
  | Slid of MLast.loc and string
  | Slist of MLast.loc and list sexpr
  | Sqid of MLast.loc and string
  | Squot of MLast.loc and string and string
  | Srec of MLast.loc and list sexpr
  | Sstring of MLast.loc and string
  | Stid of MLast.loc and string
  | Suid of MLast.loc and string ]
;

value loc_of_sexpr =
  fun [
    Sacc loc _ _ | Schar loc _ | Sexpr loc _ | Sint loc _ | Sfloat loc _ |
    Slid loc _ | Slist loc _ | Sqid loc _ | Squot loc _ _ | Srec loc _ |
    Sstring loc _ | Stid loc _ | Suid loc _ ->
    loc ]
;
value error_loc loc err =
  Stdpp.raise_with_loc loc (Stream.Error (err ^ " expected"))
;
value error se err = error_loc (loc_of_sexpr se) err;

value strm_n = "strm__";
value peek_fun loc = <:expr< Stream.peek >>;
value junk_fun loc = <:expr< Stream.junk >>;

value assoc_left_parsed_op_list =
  ["+"; "*"; "+."; "*."; "land"; "lor"; "lxor"]
;
value assoc_right_parsed_op_list = ["and"; "or"; "^"; "@"];
value and_by_couple_op_list = ["="; "<>"; "<"; ">"; "<="; ">="; "=="; "!="];

value op_apply loc e1 e2 =
  fun
  [ "and" -> <:expr< $e1$ && $e2$ >>
  | "or" -> <:expr< $e1$ || $e2$ >>
  | x -> <:expr< $lid:x$ $e1$ $e2$ >> ]
;

value string_se =
  fun
  [ Sstring loc s -> s
  | se -> error se "string" ]
;

value mod_ident_se =
  fun
  [ Suid _ s -> [Pcaml.rename_id.val s]
  | Slid _ s -> [Pcaml.rename_id.val s]
  | se -> error se "mod_ident" ]
;

value lident_expr loc s =
  if String.length s > 1 && s.[0] = '`' then
    let s = String.sub s 1 (String.length s - 1) in
    <:expr< ` $s$ >>
  else <:expr< $lid:(Pcaml.rename_id.val s)$ >>
;

value rec module_expr_se =
  fun
  [ Sexpr loc [Slid _ "functor"; Suid _ s; se1; se2] ->
      let s = Pcaml.rename_id.val s in
      let mt = module_type_se se1 in
      let me = module_expr_se se2 in
      <:module_expr< functor ($s$ : $mt$) -> $me$ >>
  | Sexpr loc [Slid _ "struct" :: sl] ->
      let mel = List.map str_item_se sl in
      <:module_expr< struct $list:mel$ end >>
  | Sexpr loc [se1; se2] ->
      let me1 = module_expr_se se1 in
      let me2 = module_expr_se se2 in
      <:module_expr< $me1$ $me2$ >>
  | Suid loc s -> <:module_expr< $uid:(Pcaml.rename_id.val s)$ >>
  | se -> error se "module expr" ]
and module_type_se =
  fun
  [ Sexpr loc [Slid _ "functor"; Suid _ s; se1; se2] ->
      let s = Pcaml.rename_id.val s in
      let mt1 = module_type_se se1 in
      let mt2 = module_type_se se2 in
      <:module_type< functor ($s$ : $mt1$) -> $mt2$ >>
  | Sexpr loc [Slid _ "sig" :: sel] ->
      let sil = List.map sig_item_se sel in
      <:module_type< sig $list:sil$ end >>
  | Sexpr loc [Slid _ "with"; se; Sexpr _ sel] ->
      let mt = module_type_se se in
      let wcl = List.map with_constr_se sel in
      <:module_type< $mt$ with $list:wcl$ >>
  | Suid loc s -> <:module_type< $uid:(Pcaml.rename_id.val s)$ >>
  | se -> error se "module type" ]
and with_constr_se =
  fun
  [ Sexpr loc [Slid _ "type"; se1; se2] ->
      let tn = mod_ident_se se1 in
      let te = ctyp_se se2 in
      MLast.WcTyp loc tn [] te
  | se -> error se "with constr" ]
and sig_item_se =
  fun
  [ Sexpr loc [Slid _ "type" :: sel] ->
      let tdl = type_declaration_list_se sel in
      <:sig_item< type $list:tdl$ >>
  | Sexpr loc [Slid _ "exception"; Suid _ c :: sel] ->
      let c = Pcaml.rename_id.val c in
      let tl = List.map ctyp_se sel in
      <:sig_item< exception $c$ of $list:tl$ >>
  | Sexpr loc [Slid _ "value"; Slid _ s; se] ->
      let s = Pcaml.rename_id.val s in
      let t = ctyp_se se in
      <:sig_item< value $s$ : $t$ >>
  | Sexpr loc [Slid _ "external"; Slid _ i; se :: sel] ->
      let i = Pcaml.rename_id.val i in
      let pd = List.map string_se sel in
      let t = ctyp_se se in
      <:sig_item< external $i$ : $t$ = $list:pd$ >>
  | Sexpr loc [Slid _ "module"; Suid _ s; se] ->
      let s = Pcaml.rename_id.val s in
      let mb = module_type_se se in
      <:sig_item< module $s$ : $mb$ >>
  | Sexpr loc [Slid _ "moduletype"; Suid _ s; se] ->
      let s = Pcaml.rename_id.val s in
      let mt = module_type_se se in
      <:sig_item< module type $s$ = $mt$ >>
  | se -> error se "sig item" ]
and str_item_se se =
  match se with
  [ Sexpr loc [Slid _ "open"; se] ->
      let s = mod_ident_se se in
      <:str_item< open $s$ >>
  | Sexpr loc [Slid _ "type" :: sel] ->
      let tdl = type_declaration_list_se sel in
      <:str_item< type $list:tdl$ >>
  | Sexpr loc [Slid _ "exception"; Suid _ c :: sel] ->
      let c = Pcaml.rename_id.val c in
      let tl = List.map ctyp_se sel in
      <:str_item< exception $c$ of $list:tl$ >>
  | Sexpr loc [Slid _ ("define" | "definerec" as r); se :: sel] ->
      let r = r = "definerec" in
      let (p, e) = fun_binding_se se (begin_se loc sel) in
      <:str_item< value $opt:r$ $p$ = $e$ >>
  | Sexpr loc [Slid _ ("define*" | "definerec*" as r) :: sel] ->
      let r = r = "definerec*" in
      let lbs = List.map let_binding_se sel in
      <:str_item< value $opt:r$ $list:lbs$ >>
  | Sexpr loc [Slid _ "external"; Slid _ i; se :: sel] ->
      let i = Pcaml.rename_id.val i in
      let pd = List.map string_se sel in
      let t = ctyp_se se in
      <:str_item< external $i$ : $t$ = $list:pd$ >>
  | Sexpr loc [Slid _ "module"; Suid _ i; se] ->
      let i = Pcaml.rename_id.val i in
      let mb = module_binding_se se in
      <:str_item< module $i$ = $mb$ >>
  | Sexpr loc [Slid _ "moduletype"; Suid _ s; se] ->
      let s = Pcaml.rename_id.val s in
      let mt = module_type_se se in
      <:str_item< module type $s$ = $mt$ >>
  | _ ->
      let loc = loc_of_sexpr se in
      let e = expr_se se in
      <:str_item< $exp:e$ >> ]
and module_binding_se se = module_expr_se se
and expr_se =
  fun
  [ Sacc loc se1 se2 ->
      let e1 = expr_se se1 in
      match se2 with
      [ Slist loc [se2] ->
          let e2 = expr_se se2 in
          <:expr< $e1$ .[ $e2$ ] >>
      | Sexpr loc [se2] ->
          let e2 = expr_se se2 in
          <:expr< $e1$ .( $e2$ ) >>
      | _ ->
          let e2 = expr_se se2 in
          <:expr< $e1$ . $e2$ >> ]
  | Slid loc s -> lident_expr loc s
  | Suid loc s -> <:expr< $uid:(Pcaml.rename_id.val s)$ >>
  | Sint loc s -> <:expr< $int:s$ >>
  | Sfloat loc s -> <:expr< $flo:s$ >>
  | Schar loc s -> <:expr< $chr:s$ >>
  | Sstring loc s -> <:expr< $str:s$ >>
  | Stid loc s -> <:expr< ~ $(Pcaml.rename_id.val s)$ >>
  | Sqid loc s -> <:expr< ? $(Pcaml.rename_id.val s)$ >>
  | Sexpr loc [] -> <:expr< () >>
  | Sexpr loc [Slid _ s; e1 :: ([_ :: _] as sel)]
    when List.mem s assoc_left_parsed_op_list ->
      let rec loop e1 =
        fun
        [ [] -> e1
        | [e2 :: el] -> loop (op_apply loc e1 e2 s) el ]
      in
      loop (expr_se e1) (List.map expr_se sel)
  | Sexpr loc [Slid _ s :: ([_; _ :: _] as sel)]
    when List.mem s assoc_right_parsed_op_list ->
      let rec loop =
        fun
        [ [] -> assert False
        | [e1] -> e1
        | [e1 :: el] ->
            let e2 = loop el in
            op_apply loc e1 e2 s ]
      in
      loop (List.map expr_se sel)
  | Sexpr loc [Slid _ s :: ([_; _ :: _] as sel)]
    when List.mem s and_by_couple_op_list ->
      let rec loop =
        fun
        [ [] | [_] -> assert False
        | [e1; e2] -> <:expr< $lid:s$ $e1$ $e2$ >>
        | [e1 :: ([e2; _ :: _] as el)] ->
            let a1 = op_apply loc e1 e2 s in
            let a2 = loop el in
            <:expr< $a1$ && $a2$ >> ]
      in
      loop (List.map expr_se sel)
  | Sexpr loc [Stid _ s; se] ->
      let e = expr_se se in
      <:expr< ~ $s$ : $e$ >>
  | Sexpr loc [Slid _ "-"; se] ->
      let e = expr_se se in
      <:expr< - $e$ >>
  | Sexpr loc [Slid _ "if"; se; se1] ->
      let e = expr_se se in
      let e1 = expr_se se1 in
      <:expr< if $e$ then $e1$ else () >>
  | Sexpr loc [Slid _ "if"; se; se1; se2] ->
      let e = expr_se se in
      let e1 = expr_se se1 in
      let e2 = expr_se se2 in
      <:expr< if $e$ then $e1$ else $e2$ >>
  | Sexpr loc [Slid _ "cond" :: sel] ->
      let rec loop =
        fun
        [ [Sexpr loc [Slid _ "else" :: sel]] -> begin_se loc sel
        | [Sexpr loc [se1 :: sel1] :: sel] ->
            let e1 = expr_se se1 in
            let e2 = begin_se loc sel1 in
            let e3 = loop sel in
            <:expr< if $e1$ then $e2$ else $e3$ >>
        | [] -> <:expr< () >>
        | [se :: _] -> error se "cond clause" ]
      in
      loop sel
  | Sexpr loc [Slid _ "while"; se :: sel] ->
      let e = expr_se se in
      let el = List.map expr_se sel in
      <:expr< while $e$ do { $list:el$ } >>
  | Sexpr loc [Slid _ "for"; Slid _ i; se1; se2 :: sel] ->
      let i = Pcaml.rename_id.val i in
      let e1 = expr_se se1 in
      let e2 = expr_se se2 in
      let el = List.map expr_se sel in
      <:expr< for $i$ = $e1$ to $e2$ do { $list:el$ } >>
  | Sexpr loc [Slid loc1 "lambda"] -> <:expr< fun [] >>
  | Sexpr loc [Slid loc1 "lambda"; sep :: sel] ->
      let e = begin_se loc1 sel in
      match ipatt_opt_se sep with
      [ Left p -> <:expr< fun $p$ -> $e$ >>
      | Right (se, sel) ->
          List.fold_right
            (fun se e ->
               let p = ipatt_se se in
               <:expr< fun $p$ -> $e$ >>)
            [se :: sel] e ]
  | Sexpr loc [Slid _ "lambda_match" :: sel] ->
      let pel = List.map (match_case loc) sel in
      <:expr< fun [ $list:pel$ ] >>
  | Sexpr loc [Slid _ ("let" | "letrec" as r) :: sel] ->
      match sel with
      [ [Sexpr _ sel1 :: sel2] ->
          let r = r = "letrec" in
          let lbs = List.map let_binding_se sel1 in
          let e = begin_se loc sel2 in
          <:expr< let $opt:r$ $list:lbs$ in $e$ >>
      | [Slid _ n; Sexpr _ sl :: sel] ->
          let n = Pcaml.rename_id.val n in
          let (pl, el) =
            List.fold_right
              (fun se (pl, el) ->
                 match se with
                 [ Sexpr _ [se1; se2] ->
                     ([patt_se se1 :: pl], [expr_se se2 :: el])
                 | se -> error se "named let" ])
              sl ([], [])
          in
          let e1 =
            List.fold_right (fun p e -> <:expr< fun $p$ -> $e$ >>) pl
              (begin_se loc sel)
          in
          let e2 =
            List.fold_left (fun e1 e2 -> <:expr< $e1$ $e2$ >>)
              <:expr< $lid:n$ >> el
          in
          <:expr< let rec $lid:n$ = $e1$ in $e2$ >>
      | [se :: _] -> error se "let_binding"
      | _ -> error_loc loc "let_binding" ]
  | Sexpr loc [Slid _ "let*" :: sel] ->
      match sel with
      [ [Sexpr _ sel1 :: sel2] ->
          List.fold_right
            (fun se ek ->
               let (p, e) = let_binding_se se in
               <:expr< let $p$ = $e$ in $ek$ >>)
            sel1 (begin_se loc sel2)
      | [se :: _] -> error se "let_binding"
      | _ -> error_loc loc "let_binding" ]
  | Sexpr loc [Slid _ "match"; se :: sel] ->
      let e = expr_se se in
      let pel = List.map (match_case loc) sel in
      <:expr< match $e$ with [ $list:pel$ ] >>
  | Sexpr loc [Slid _ "parser" :: sel] ->
      let e =
        match sel with
        [ [(Slid _ _ as se) :: sel] ->
            let p = patt_se se in
            let pc = parser_cases_se loc sel in
            <:expr< let $p$ = Stream.count $lid:strm_n$ in $pc$ >>
        | _ -> parser_cases_se loc sel ]
      in
      <:expr< fun ($lid:strm_n$ : Stream.t _) -> $e$ >>
  | Sexpr loc [Slid _ "match_with_parser"; se :: sel] ->
      let me = expr_se se in
      let (bpo, sel) =
        match sel with
        [ [(Slid _ _ as se) :: sel] -> (Some (patt_se se), sel)
        | _ -> (None, sel) ]
      in
      let pc = parser_cases_se loc sel in
      let e =
        match bpo with
        [ Some bp -> <:expr< let $bp$ = Stream.count $lid:strm_n$ in $pc$ >>
        | None -> pc ]
      in
      match me with
      [ <:expr< $lid:x$ >> when x = strm_n -> e
      | _ -> <:expr< let ($lid:strm_n$ : Stream.t _) = $me$ in $e$ >> ]
  | Sexpr loc [Slid _ "try"; se :: sel] ->
      let e = expr_se se in
      let pel = List.map (match_case loc) sel in
      <:expr< try $e$ with [ $list:pel$ ] >>
  | Sexpr loc [Slid _ "begin" :: sel] ->
      let el = List.map expr_se sel in
      <:expr< do { $list:el$ } >>
  | Sexpr loc [Slid _ ":="; se1; se2] ->
      let e1 = expr_se se1 in
      let e2 = expr_se se2 in
      <:expr< $e1$ := $e2$ >>
  | Sexpr loc [Slid _ "values" :: sel] ->
      let el = List.map expr_se sel in
      <:expr< ( $list:el$ ) >>
  | Srec loc [Slid _ "with"; se :: sel] ->
      let e = expr_se se in
      let lel = List.map (label_expr_se loc) sel in
      <:expr< { ($e$) with $list:lel$ } >>
  | Srec loc sel ->
      let lel = List.map (label_expr_se loc) sel in
      <:expr< { $list:lel$ } >>
  | Sexpr loc [Slid _ ":"; se1; se2] ->
      let e = expr_se se1 in
      let t = ctyp_se se2 in
      <:expr< ( $e$ : $t$ ) >>
  | Sexpr loc [se] ->
      let e = expr_se se in
      <:expr< $e$ () >>
  | Sexpr loc [Slid _ "assert"; se] ->
      let e = expr_se se in
      <:expr< assert $e$ >>
  | Sexpr loc [Slid _ "lazy"; se] ->
      let e = expr_se se in
      <:expr< lazy $e$ >>
  | Sexpr loc [se :: sel] ->
      List.fold_left
        (fun e se ->
           let e1 = expr_se se in
           <:expr< $e$ $e1$ >>)
        (expr_se se) sel
  | Slist loc sel ->
      let rec loop =
        fun
        [ [] -> <:expr< [] >>
        | [se1; Slid _ "."; se2] ->
            let e = expr_se se1 in
            let el = expr_se se2 in
            <:expr< [$e$ :: $el$] >>
        | [se :: sel] ->
            let e = expr_se se in
            let el = loop sel in
            <:expr< [$e$ :: $el$] >> ]
      in
      loop sel
  | Squot loc typ txt -> Pcaml.handle_expr_quotation loc (typ, txt) ]
and begin_se loc =
  fun
  [ [] -> <:expr< () >>
  | [se] -> expr_se se
  | sel ->
      let el = List.map expr_se sel in
      let loc = Stdpp.encl_loc (loc_of_sexpr (List.hd sel)) loc in
      <:expr< do { $list:el$ } >> ]
and let_binding_se =
  fun
  [ Sexpr loc [se :: sel] ->
      let e = begin_se loc sel in
      match ipatt_opt_se se with
      [ Left p -> (p, e)
      | Right _ -> fun_binding_se se e ]
  | se -> error se "let_binding" ]
and fun_binding_se se e =
  match se with
  [ Sexpr _ [Slid _ "values" :: _] -> (ipatt_se se, e)
  | Sexpr _ [Slid loc s :: sel] ->
      let s = Pcaml.rename_id.val s in
      let e =
        List.fold_right
          (fun se e ->
             let loc =
               Stdpp.encl_loc (loc_of_sexpr se) (MLast.loc_of_expr e)
             in
             let p = ipatt_se se in
             <:expr< fun $p$ -> $e$ >>)
          sel e
      in
      let p = <:patt< $lid:s$ >> in
      (p, e)
  | _ -> (ipatt_se se, e) ]
and match_case loc =
  fun
  [ Sexpr loc [Sexpr _ [Slid _ "when"; se; sew] :: sel] ->
      (patt_se se, Some (expr_se sew), begin_se loc sel)
  | Sexpr loc [se :: sel] -> (patt_se se, None, begin_se loc sel)
  | se -> error se "match_case" ]
and label_expr_se loc =
  fun
  [ Sexpr _ [se1; se2] -> (patt_se se1, expr_se se2)
  | se -> error se "label_expr" ]
and label_patt_se loc =
  fun
  [ Sexpr _ [se1; se2] -> (patt_se se1, patt_se se2)
  | se -> error se "label_patt" ]
and parser_cases_se loc =
  fun
  [ [] -> <:expr< raise Stream.Failure >>
  | [Sexpr loc [Sexpr _ spsel :: act] :: sel] ->
      let ekont _ = parser_cases_se loc sel in
      let act =
        match act with
        [ [se] -> expr_se se
        | [sep; se] ->
            let p = patt_se sep in
            let e = expr_se se in
            <:expr< let $p$ = Stream.count $lid:strm_n$ in $e$ >>
        | _ -> error_loc loc "parser_case" ]
      in
      stream_pattern_se loc act ekont spsel
  | [se :: _] -> error se "parser_case" ]
and stream_pattern_se loc act ekont =
  fun
  [ [] -> act
  | [se :: sel] ->
      let ckont err = <:expr< raise (Stream.Error $err$) >> in
      let skont = stream_pattern_se loc act ckont sel in
      stream_pattern_component skont ekont <:expr< "" >> se ]
and stream_pattern_component skont ekont err =
  fun
  [ Sexpr loc [Slid _ "`"; se :: wol] ->
      let wo =
        match wol with
        [ [se] -> Some (expr_se se)
        | [] -> None
        | _ -> error_loc loc "stream_pattern_component" ]
      in
      let e = peek_fun loc in
      let p = patt_se se in
      let j = junk_fun loc in
      let k = ekont err in
      <:expr< match $e$ $lid:strm_n$ with
               [ Some $p$ $when:wo$ -> do { $j$ $lid:strm_n$ ; $skont$ }
               | _ -> $k$ ] >>
  | Sexpr loc [se1; se2] ->
      let p = patt_se se1 in
      let e =
        let e = expr_se se2 in
        <:expr< try Some ($e$ $lid:strm_n$) with [ Stream.Failure -> None ] >>
      in
      let k = ekont err in
      <:expr< match $e$ with [ Some $p$ -> $skont$ | _ -> $k$ ] >>
  | Sexpr loc [Slid _ "?"; se1; se2] ->
      stream_pattern_component skont ekont (expr_se se2) se1
  | Slid loc s ->
      let s = Pcaml.rename_id.val s in
      <:expr< let $lid:s$ = $lid:strm_n$ in $skont$ >>
  | se -> error se "stream_pattern_component" ]
and patt_se =
  fun
  [ Sacc loc se1 se2 ->
      let p1 = patt_se se1 in
      let p2 = patt_se se2 in
      <:patt< $p1$ . $p2$ >>
  | Slid loc "_" -> <:patt< _ >>
  | Slid loc s -> <:patt< $lid:(Pcaml.rename_id.val s)$ >>
  | Suid loc s -> <:patt< $uid:(Pcaml.rename_id.val s)$ >>
  | Sint loc s -> <:patt< $int:s$ >>
  | Sfloat loc s -> <:patt< $flo:s$ >>
  | Schar loc s -> <:patt< $chr:s$ >>
  | Sstring loc s -> <:patt< $str:s$ >>
  | Stid loc _ -> error_loc loc "patt"
  | Sqid loc _ -> error_loc loc "patt"
  | Srec loc sel ->
      let lpl = List.map (label_patt_se loc) sel in
      <:patt< { $list:lpl$ } >>
  | Sexpr loc [Slid _ ":"; se1; se2] ->
      let p = patt_se se1 in
      let t = ctyp_se se2 in
      <:patt< ($p$ : $t$) >>
  | Sexpr loc [Slid _ "or"; se :: sel] ->
      List.fold_left
        (fun p se ->
           let p1 = patt_se se in
           <:patt< $p$ | $p1$ >>)
        (patt_se se) sel
  | Sexpr loc [Slid _ "range"; se1; se2] ->
      let p1 = patt_se se1 in
      let p2 = patt_se se2 in
      <:patt< $p1$ .. $p2$ >>
  | Sexpr loc [Slid _ "values" :: sel] ->
      let pl = List.map patt_se sel in
      <:patt< ( $list:pl$ ) >>
  | Sexpr loc [Slid _ "as"; se1; se2] ->
      let p1 = patt_se se1 in
      let p2 = patt_se se2 in
      <:patt< ($p1$ as $p2$) >>
  | Sexpr loc [se :: sel] ->
      List.fold_left
        (fun p se ->
           let p1 = patt_se se in
           <:patt< $p$ $p1$ >>)
        (patt_se se) sel
  | Sexpr loc [] -> <:patt< () >>
  | Slist loc sel ->
      let rec loop =
        fun
        [ [] -> <:patt< [] >>
        | [se1; Slid _ "."; se2] ->
            let p = patt_se se1 in
            let pl = patt_se se2 in
            <:patt< [$p$ :: $pl$] >>
        | [se :: sel] ->
            let p = patt_se se in
            let pl = loop sel in
            <:patt< [$p$ :: $pl$] >> ]
      in
      loop sel
  | Squot loc typ txt -> Pcaml.handle_patt_quotation loc (typ, txt) ]
and ipatt_se se =
  match ipatt_opt_se se with
  [ Left p -> p
  | Right (se, _) -> error se "ipatt" ]
and ipatt_opt_se =
  fun
  [ Slid loc "_" -> Left <:patt< _ >>
  | Slid loc s -> Left <:patt< $lid:(Pcaml.rename_id.val s)$ >>
  | Stid loc s -> Left <:patt< ~ $(Pcaml.rename_id.val s)$ >>
  | Sqid loc s -> Left <:patt< ? $(Pcaml.rename_id.val s)$ >>
  | Sexpr loc [Sqid _ s; se] ->
      let s = Pcaml.rename_id.val s in
      let e = expr_se se in
      Left <:patt< ? ( $lid:s$ = $e$ ) >>
  | Sexpr loc [Slid _ ":"; se1; se2] ->
      let p = ipatt_se se1 in
      let t = ctyp_se se2 in
      Left <:patt< ($p$ : $t$) >>
  | Sexpr loc [Slid _ "values" :: sel] ->
      let pl = List.map ipatt_se sel in
      Left <:patt< ( $list:pl$ ) >>
  | Sexpr loc [] -> Left <:patt< () >>
  | Sexpr loc [se :: sel] -> Right (se, sel)
  | se -> error se "ipatt" ]
and type_declaration_list_se =
  fun
  [ [se1; se2 :: sel] ->
      let (n1, loc1, tpl) =
        match se1 with
        [ Sexpr _ [Slid loc n :: sel] ->
            (n, loc, List.map type_parameter_se sel)
        | Slid loc n -> (n, loc, [])
        | se -> error se "type declaration" ]
      in
      [((loc1, Pcaml.rename_id.val n1), tpl, ctyp_se se2, []) ::
       type_declaration_list_se sel]
  | [] -> []
  | [se :: _] -> error se "type_declaration" ]
and type_parameter_se =
  fun
  [ Slid _ s when String.length s >= 2 && s.[0] = ''' ->
      (String.sub s 1 (String.length s - 1), (False, False))
  | se -> error se "type_parameter" ]
and ctyp_se =
  fun
  [ Sexpr loc [Slid _ "sum" :: sel] ->
      let cdl = List.map constructor_declaration_se sel in
      <:ctyp< [ $list:cdl$ ] >>
  | Srec loc sel ->
      let ldl = List.map label_declaration_se sel in
      <:ctyp< { $list:ldl$ } >>
  | Sexpr loc [Slid _ "->" :: ([_; _ :: _] as sel)] ->
      let rec loop =
        fun
        [ [] -> assert False
        | [se] -> ctyp_se se
        | [se :: sel] ->
            let t1 = ctyp_se se in
            let loc = Stdpp.encl_loc (loc_of_sexpr se) loc in
            let t2 = loop sel in
            <:ctyp< $t1$ -> $t2$ >> ]
      in
      loop sel
  | Sexpr loc [Slid _ "*" :: sel] ->
      let tl = List.map ctyp_se sel in
      <:ctyp< ($list:tl$) >>
  | Sexpr loc [se :: sel] ->
      List.fold_left
        (fun t se ->
           let t2 = ctyp_se se in
           <:ctyp< $t$ $t2$ >>)
        (ctyp_se se) sel
  | Sacc loc se1 se2 ->
      let t1 = ctyp_se se1 in
      let t2 = ctyp_se se2 in
      <:ctyp< $t1$ . $t2$ >>
  | Slid loc "_" -> <:ctyp< _ >>
  | Slid loc s ->
      if s.[0] = ''' then
        let s = String.sub s 1 (String.length s - 1) in
        <:ctyp< '$s$ >>
      else <:ctyp< $lid:(Pcaml.rename_id.val s)$ >>
  | Suid loc s -> <:ctyp< $uid:(Pcaml.rename_id.val s)$ >>
  | se -> error se "ctyp" ]
and constructor_declaration_se =
  fun
  [ Sexpr loc [Suid _ ci :: sel] ->
      (loc, Pcaml.rename_id.val ci, List.map ctyp_se sel)
  | se -> error se "constructor_declaration" ]
and label_declaration_se =
  fun
  [ Sexpr loc [Slid _ lab; Slid _ "mutable"; se] ->
      (loc, Pcaml.rename_id.val lab, True, ctyp_se se)
  | Sexpr loc [Slid _ lab; se] ->
      (loc, Pcaml.rename_id.val lab, False, ctyp_se se)
  | se -> error se "label_declaration" ]
;

value directive_se =
  fun
  [ Sexpr _ [Slid _ s] -> (s, None)
  | Sexpr _ [Slid _ s; se] ->
      let e = expr_se se in
      (s, Some e)
  | se -> error se "directive" ]
;

(* Parser *)

Pcaml.syntax_name.val := "Scheme";
Pcaml.no_constructors_arity.val := False;

do {
  Grammar.Unsafe.gram_reinit gram (lexer_gmake ());
  Grammar.Unsafe.clear_entry interf;
  Grammar.Unsafe.clear_entry implem;
  Grammar.Unsafe.clear_entry top_phrase;
  Grammar.Unsafe.clear_entry use_file;
  Grammar.Unsafe.clear_entry module_type;
  Grammar.Unsafe.clear_entry module_expr;
  Grammar.Unsafe.clear_entry sig_item;
  Grammar.Unsafe.clear_entry str_item;
  Grammar.Unsafe.clear_entry expr;
  Grammar.Unsafe.clear_entry patt;
  Grammar.Unsafe.clear_entry ctyp;
  Grammar.Unsafe.clear_entry let_binding;
  Grammar.Unsafe.clear_entry type_declaration;
  Grammar.Unsafe.clear_entry class_type;
  Grammar.Unsafe.clear_entry class_expr;
  Grammar.Unsafe.clear_entry class_sig_item;
  Grammar.Unsafe.clear_entry class_str_item
};

Pcaml.parse_interf.val := Grammar.Entry.parse interf;
Pcaml.parse_implem.val := Grammar.Entry.parse implem;

value sexpr = Grammar.Entry.create gram "sexpr";

value rec leftify =
  fun
  [ Sacc loc1 se1 se2 ->
      match leftify se2 with
      [ Sacc loc2 se2 se3 -> Sacc loc1 (Sacc loc2 se1 se2) se3
      | se2 -> Sacc loc1 se1 se2 ]
  | x -> x ]
;

EXTEND
  GLOBAL: implem interf top_phrase use_file str_item sig_item expr patt sexpr;
  implem:
    [ [ "#"; se = sexpr ->
          let (n, dp) = directive_se se in
          ([(<:str_item< # $n$ $opt:dp$ >>, loc)], True)
      | si = str_item; x = SELF ->
          let (sil, stopped) = x in
          let loc = MLast.loc_of_str_item si in
          ([(si, loc) :: sil], stopped)
      | EOI -> ([], False) ] ]
  ;
  interf:
    [ [ "#"; se = sexpr ->
          let (n, dp) = directive_se se in
          ([(<:sig_item< # $n$ $opt:dp$ >>, loc)], True)
      | si = sig_item; x = SELF ->
          let (sil, stopped) = x in
          let loc = MLast.loc_of_sig_item si in
          ([(si, loc) :: sil], stopped)
      | EOI -> ([], False) ] ]
  ;
  top_phrase:
    [ [ "#"; se = sexpr ->
          let (n, dp) = directive_se se in
          Some <:str_item< # $n$ $opt:dp$ >>
      | se = sexpr -> Some (str_item_se se)
      | EOI -> None ] ]
  ;
  use_file:
    [ [ "#"; se = sexpr ->
          let (n, dp) = directive_se se in
          ([<:str_item< # $n$ $opt:dp$ >>], True)
      | si = str_item; x = SELF ->
          let (sil, stopped) = x in
          ([si :: sil], stopped)
      | EOI -> ([], False) ] ]
  ;
  str_item:
    [ [ se = sexpr -> str_item_se se
      | e = expr -> <:str_item< $exp:e$ >> ] ]
  ;
  sig_item:
    [ [ se = sexpr -> sig_item_se se ] ]
  ;
  expr:
    [ "top"
      [ se = sexpr -> expr_se se ] ]
  ;
  patt:
    [ [ se = sexpr -> patt_se se ] ]
  ;
  sexpr:
    [ [ se1 = sexpr_dot; se2 = SELF -> leftify (Sacc loc se1 se2) ]
    | [ "("; sl = LIST0 sexpr; ")" -> Sexpr loc sl
      | "("; sl = LIST0 sexpr; ")."; se = SELF ->
          leftify (Sacc loc (Sexpr loc sl) se)
      | "["; sl = LIST0 sexpr; "]" -> Slist loc sl
      | "{"; sl = LIST0 sexpr; "}" -> Srec loc sl
      | a = pa_extend_keyword -> Slid loc a
      | s = LIDENT -> Slid loc s
      | s = UIDENT -> Suid loc s
      | s = TILDEIDENT -> Stid loc s
      | s = QUESTIONIDENT -> Sqid loc s
      | s = INT -> Sint loc s
      | s = FLOAT -> Sfloat loc s
      | s = CHAR -> Schar loc s
      | s = STRING -> Sstring loc s
      | s = QUOT ->
          let i = String.index s ':' in
          let typ = String.sub s 0 i in
          let txt = String.sub s (i + 1) (String.length s - i - 1) in
          Squot loc typ txt ] ]
  ;
  sexpr_dot:
    [ [ s = LIDENTDOT -> Slid loc s
      | s = UIDENTDOT -> Suid loc s ] ]
  ;
  pa_extend_keyword:
    [ [ "_" -> "_"
      | "," -> ","
      | "=" -> "="
      | ":" -> ":"
      | "." -> "."
      | "/" -> "/" ] ]
  ;
END;
