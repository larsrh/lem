(**************************************************************************)
(*                        Lem                                             *)
(*                                                                        *)
(*          Dominic Mulligan, University of Cambridge                     *)
(*          Francesco Zappa Nardelli, INRIA Paris-Rocquencourt            *)
(*          Gabriel Kerneis, University of Cambridge                      *)
(*          Kathy Gray, University of Cambridge                           *)
(*          Peter Boehm, University of Cambridge (while working on Lem)   *)
(*          Peter Sewell, University of Cambridge                         *)
(*          Scott Owens, University of Kent                               *)
(*          Thomas Tuerk, University of Cambridge                         *)
(*                                                                        *)
(*  The Lem sources are copyright 2010-2013                               *)
(*  by the UK authors above and Institut National de Recherche en         *)
(*  Informatique et en Automatique (INRIA).                               *)
(*                                                                        *)
(*  All files except ocaml-lib/pmap.{ml,mli} and ocaml-libpset.{ml,mli}   *)
(*  are distributed under the license below.  The former are distributed  *)
(*  under the LGPLv2, as in the LICENSE file.                             *)
(*                                                                        *)
(*                                                                        *)
(*  Redistribution and use in source and binary forms, with or without    *)
(*  modification, are permitted provided that the following conditions    *)
(*  are met:                                                              *)
(*  1. Redistributions of source code must retain the above copyright     *)
(*  notice, this list of conditions and the following disclaimer.         *)
(*  2. Redistributions in binary form must reproduce the above copyright  *)
(*  notice, this list of conditions and the following disclaimer in the   *)
(*  documentation and/or other materials provided with the distribution.  *)
(*  3. The names of the authors may not be used to endorse or promote     *)
(*  products derived from this software without specific prior written    *)
(*  permission.                                                           *)
(*                                                                        *)
(*  THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS    *)
(*  OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED     *)
(*  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE    *)
(*  ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY       *)
(*  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL    *)
(*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE     *)
(*  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS         *)
(*  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER  *)
(*  IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR       *)
(*  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN   *)
(*  IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.                         *)
(**************************************************************************)

exception Backend of string

let (^^) = Ulib.Text.(^^^)
let r = Ulib.Text.of_latin1

type id_annot =  (* kind annotation for latex'd identifiers *)
  | Term_const
  | Term_ctor
  | Term_field 
  | Term_method 
  | Term_var 
  | Term_var_toplevel
  | Term_spec 
  | Type_ctor
  | Type_var
  | Nexpr_var
  | Module_name
  | Class_name
  | Target


type block_type =
    Block_type_hbox
  | Block_type_vbox of int
  | Block_type_hvbox of int
  | Block_type_hovbox of int

let open_block_type ff = function
    Block_type_hbox     -> Format.pp_open_hbox ff ()
  | Block_type_vbox d   -> Format.pp_open_vbox ff d
  | Block_type_hvbox d  -> Format.pp_open_hvbox ff d
  | Block_type_hovbox d -> Format.pp_open_hovbox ff d


type t = 
  | Empty                          (* Empty output *)
  | Kwd of string                  (* Keyword *)
  | Ident of id_annot * Ulib.Text.t  (* Identifier *)
  | Num of int                     (* Literal int *)
  | Inter of Ast.lex_skip          (* Interstitial: Comment (currently including (* *), Pure whitespace [' ''\t']+, or Newline *)
  | Str of Ulib.Text.t             (* String literal, without surrounding "" *)
  | Err of string                  (* Causes to_rope to raise an exception *) 
  | Meta of string                 (* Data that is not subject to the target lexical convention *)
  | Texspace                       (* Force latex space except at start or end of line *)
  | Internalspace                  (* An internal marker for space *)
  | Ensure_newline                 (* enters a newline if not already at beginning of line *)
  | Cons of t * t                  (* Cons *)
  | Block of bool * block_type * t (* Block either autoformated or not *)
  | Break_hint of bool * int        (* Possible line break with indentation *)

type t' =
  | Kwd' of string
  | Ident' of Ulib.Text.t
  | Num' of int

let emp = Empty

let kwd t = Kwd(t)

let id a t = Ident(a,t)

let num t = Num(t)

let ws = function
  | None -> Empty
  | Some([]) -> Empty
  | Some (ts) -> 
      List.fold_left (fun o1 o2 -> Cons(o1,o2)) Empty 
        (List.map 
           (fun t -> Inter t)
           (List.rev ts))

let str s = Str(s)

let err s = Err(s)

let meta s = Meta(s)

let texspace = Texspace
              
let (^) o1 o2 = 
  match (o1,o2) with
    | (Empty, _) -> o2
    | (_, Empty) -> o1
    | _ -> Cons(o1,o2)

let block_h b i t = Block (b, Block_type_hbox, t)
let block_v b i t = Block (b, Block_type_vbox i, t)
let block_hv b i t = Block (b, Block_type_hvbox i, t)
let block_hov b i t = Block (b, Block_type_hovbox i, t)
let block = block_hov 

let ensure_newline = Ensure_newline 
let break_hint b j = Break_hint (b, j)
let break_hint_cut = Break_hint (false, 0)
let break_hint_space j = Break_hint (true, j)

let rec flat = function
  | [] -> Empty
  | x::y -> x ^ flat y

let rec concat o1 = function
  | [] -> Empty
  | [x] -> x
  | x::y -> x ^ o1 ^ concat o1 y

let quote_string quote_char s = quote_char ^^ s ^^ quote_char

let conv = function
  | Kwd(s) -> Kwd'(s)
  | Ident(a,r) -> Ident'(r)
  | Num(i) -> Num'(i)
  | _ -> assert false

let ns need_space t1 t2 =
  match (t1,t2) with
    | ((Empty | Inter _ | Str _ | Err _ | Meta _ | Texspace | Internalspace | Ensure_newline | Break_hint _), _) -> false
    | (_, (Empty | Inter _ | Str _ | Err _ | Meta _ | Texspace | Internalspace | Ensure_newline | Break_hint _)) -> false
    | _ -> need_space (conv t1) (conv t2)
    

(* ******** *)
(* Debug pp *)
(* ******** *)


let pp_raw_id_annot = function
  | Term_const         -> r"Term_const"       
  | Term_ctor          -> r"Term_ctor"        
  | Term_field         -> r"Term_field"       
  | Term_method        -> r"Term_method"      
  | Term_var           -> r"Term_var"         
  | Term_var_toplevel  -> r"Term_var_toplevel"
  | Term_spec          -> r"Term_spec"        
  | Type_ctor          -> r"Type_ctor"        
  | Type_var           -> r"Type_var"         
  | Module_name        -> r"Module_name"      
  | Class_name         -> r"Class_name"       
  | Target             -> r"Target"           
  | Nexpr_var          -> r"Nexpr_var"

let pp_raw_bool = function
  | true  -> r"true"
  | false -> r"false"

let rec ml_comment_to_rope = function
  | Ast.Chars(r) -> r
  | Ast.Comment(coms) -> r"(*" ^^ Ulib.Text.concat (r"") (List.map ml_comment_to_rope coms) ^^ r"*)"

let rec pp_raw_t t = 
  match t with
  | Empty -> r"Empty"
  | Kwd(s) -> r"Kwd(" ^^ Ulib.Text.of_latin1 s ^^r")"
  | Ident(a,rr) -> r"Ident(" ^^ pp_raw_id_annot a ^^ r"," ^^ rr ^^ r")"
  | Num(i) -> r"Num(" ^^  Ulib.Text.of_latin1 (string_of_int i) ^^ r")"
  | Inter(Ast.Com(rr)) -> r"Inter(Ast.Com(" ^^ ml_comment_to_rope rr ^^ r")"
  | Inter(Ast.Ws(rr)) -> r"Inter(Ast.Ws(" ^^ rr ^^ r")"
  | Inter(Ast.Nl) -> r"Inter(Ast.Nl)"
  | Str(s) -> r"Str(" ^^ s ^^ r")"
  | Err(s) -> r"Str(" ^^ Ulib.Text.of_latin1 s ^^ r")"
  | Meta(s) -> r"Str(" ^^ Ulib.Text.of_latin1 s ^^ r")"
  | Texspace -> r"Texspace"
  | Ensure_newline -> r"Ensure_newline"
  | Cons(t1,t2) -> r"Cons(" ^^ pp_raw_t t1 ^^ r"," ^^ pp_raw_t t2 ^^ r")"
  | Block(b,d,t) -> r"Block(" ^^ pp_raw_bool b ^^ r"," ^^ pp_raw_t t ^^ r")"
  | Break_hint _ -> r"Breakhint"
  | Internalspace -> r"Internalspace"




(* turns a single, unstructered Output.t into a string *)
let to_rope_single quote_char lex_skips_to_rope preserve_ws t : Ulib.Text.t = 
  match t with
    | Empty -> r""
    | Kwd(s) -> Ulib.Text.of_latin1 s
    | Ident(a,r) -> r
    | Num(i) -> Ulib.Text.of_latin1 (string_of_int i)
    | Inter(i) -> begin 
        match i with 
         | Ast.Com(r) -> lex_skips_to_rope i
         | (Ast.Nl | Ast.Ws _)  -> if preserve_ws then lex_skips_to_rope i else r""
      end
    | Str(s) -> quote_string quote_char s
    | Err(s) -> raise (Backend(s))
    | Meta(s) -> Ulib.Text.of_latin1 s
    | Texspace -> r""
    | Internalspace -> r" "
    | Break_hint _ -> r""
    | Ensure_newline -> r""
    | _ -> raise (Reporting_basic.err_unreachable false Ast.Unknown "structured output in to_rope_single")

let rec is_drop_t preserve_ws t =
  match t with
    | Empty -> true
    | Texspace -> true
    | Break_hint _ -> true
    | Inter(i) -> begin 
        match i with 
         | Ast.Com(r) -> false
         | (Ast.Nl | Ast.Ws _)  -> not preserve_ws 
      end
    | Block (_, _, t) -> is_drop_t preserve_ws t
    | Cons(t1,t2) -> is_drop_t preserve_ws t1 && is_drop_t preserve_ws t2
    | _ -> false

let rec get_first_t (preserve_ws : bool) (t : t) : t =
  match t with
    | Block (_, _, t) -> get_first_t preserve_ws t
    | Cons(t1,t2) -> get_first_t preserve_ws (if is_drop_t preserve_ws t1 then t2 else t1)
    | _ -> t

let rec get_last_t (preserve_ws : bool) (t : t) : t =
  match t with
    | Block (_, _, t) -> get_last_t preserve_ws t
    | Cons(t1,t2) -> get_last_t preserve_ws (if is_drop_t preserve_ws t2 then t1 else t2)
    | _ -> t

let rec cleanup_t preserve_ws need_space t =
begin
  let rec mk_cons = function 
    | [] -> Empty
    | [x] -> x
    | (x :: ys) -> Cons (x, mk_cons ys) 
  in

  let rec add_delete_space = function 
    | [] -> []
    | [t] -> [t]
    | (t1 :: t2 :: ts) -> 
      let t1' = get_last_t preserve_ws t1 in
      let t2' = get_first_t preserve_ws t2 in
      if ns need_space t1' t2' then
        (t1 :: Internalspace :: (add_delete_space (t2 :: ts)))
      else
        (t1 :: (add_delete_space (t2 :: ts)))
  in

  
  let rec clean_space = function
    | [] -> []
    | (Internalspace :: Internalspace :: ts) -> clean_space (Internalspace :: ts)
    | (Break_hint (i, j) :: Break_hint (i', j') :: ts) -> clean_space (Break_hint ((i || i'), (j+j')) :: ts)
    | (Break_hint (i, j) :: Internalspace :: ts) -> clean_space (Break_hint (true, j) :: ts)
    | (Internalspace :: Break_hint (i, j) :: ts) -> clean_space (Break_hint (true, j) :: ts)
    | (t :: ts) -> t :: (clean_space ts)
  in

  let rec extract_ws = function
    | Cons (Internalspace, t) -> let (sl, t') = extract_ws t in (Internalspace :: sl, t')
    | Cons (Break_hint (i,j), t) -> let (sl, t') = extract_ws t in (Break_hint (i,j) :: sl, t')
    | t -> ([], t)
  in
   
  let rec flatten t : t list =
  match t with
    | Empty -> []
    | Texspace -> [Internalspace]
    | Inter(i) -> begin 
        match i with 
         | Ast.Com(r) -> [t] @ (if preserve_ws then [] else [Internalspace])
         | Ast.Nl -> [Break_hint (false, 0)]
         | Ast.Ws _ -> if preserve_ws then [t] else [Internalspace]
      end
    | Block (_, _, Block (b, ty, t)) -> flatten (Block (b, ty, t))
    | Block (b, ty, t) -> 
      let (sl, t') = extract_ws (cleanup_t preserve_ws need_space t) in
      (sl @ [Block (b, ty, t')])
    | Cons(t1,t2) -> flatten t1 @ flatten t2
    | _ -> [t]
  in

  mk_cons (add_delete_space (clean_space (flatten t)))
end

let to_rope quote_char lex_skips_to_rope need_space t = 
  let rec to_rope_help (p : int) (t : t) : (Ulib.Text.t list * Ulib.Text.t * (int * t * t)) = match t with
    | Ensure_newline -> let res = r"" in ((if p = 0 then [] else [lex_skips_to_rope Ast.Nl]), res, (0, t, t))
    | Block (b, bty, t) -> if b then to_rope_help_block p (Block (b, bty, t)) else to_rope_help p t
    | Cons(t1,t2) -> 
      if (is_drop_t true t1) then to_rope_help p t2 else
      if (is_drop_t true t2) then to_rope_help p t1 else
      begin        
        let (rL1,r1, (p1, t1', t2')) = to_rope_help p  t1 in
        let (rL2,r2, (p2, t3', t4')) = to_rope_help p1 t2 in
        let sp = if ns need_space t2' t3' then r" " else r"" in

        let (rL3, r3) = match rL2 with [] -> ([], r1 ^^ sp ^^ r2) | (r :: rl) -> ((r1 ^^ sp ^^ r) :: rl, r2) in
        (rL1 @ rL3, r3, (p2, t1', t4'))
      end
    | _ -> (* simple, single statement *) 
      begin
        let res = to_rope_single quote_char lex_skips_to_rope true t in
        let is_nl = (match t with Inter(Ast.Nl) -> true | _ -> false) in
        if is_nl then ([res], r"", (0, t, t)) else 
                      ([], res, (p + Ulib.Text.length res, t, t))
      end
  and to_rope_help_block p t =
  begin
    let _ = Format.flush_str_formatter () in
    let rec aux (t : t) : unit = match t with
    | Ensure_newline -> (
        Format.pp_force_newline Format.str_formatter ())
    | Break_hint (i,j) -> (
        Format.pp_print_break Format.str_formatter (if i then 1 else 0) j)
    | Block (b, ty, t) -> begin
        let _ = open_block_type Format.str_formatter ty in
        let res = aux t in
        let _ = Format.pp_close_box Format.str_formatter () in
        res
      end
    | Cons(t1,t2) -> 
      begin        
        let _ = aux t1 in
        let _ = aux t2 in
        ()
      end
    | _ -> (* simple, single statement *) 
      begin
        let res = to_rope_single quote_char lex_skips_to_rope false t in
        let _ = Format.pp_print_string Format.str_formatter (Ulib.Text.to_string res) in
        ()
      end
   in
   let t' = cleanup_t false need_space t in
   let t'' = match t' with
            | Cons ((Internalspace | Break_hint _), t'') ->
                let _ = Format.pp_print_string Format.str_formatter " " in
                t''
            | t'' -> t''
   in                  
   let p' = (if p > 20 then (Format.pp_print_break Format.str_formatter 0 2; 0) else p) in
   let _ = Format.pp_open_hvbox Format.str_formatter p' in
   let _ = aux t'' in
   let _ = Format.pp_close_box Format.str_formatter () in
   let s = Format.flush_str_formatter () in
   ([], r s, (0, Kwd s, Kwd s))
  end
  in
  let (rL,r',_) = to_rope_help 0 t in
    Ulib.Text.concat (r"") (rL @ [r']) 




(* ************* *)
(* LaTeX backend *)
(* ************* *)

let tex_command_prefix = r"LEM"  (* for LaTeX commands in generated .tex and -inc.tex files *)
let tex_label_prefix   = r"lem:" (* for LaTeX labels in generated .tex and -inc.tex files *)
let tex_sty_prefix     = r"lem"  (* for LaTeX commands in the lem.sty file *)

(* escaping of Lem source names to use in LaTeX command names
 (probably it needs to be more aggressive)
 (and it isn't injective, so we should do some global check or rename too...) *)
let tex_command_escape rr = 
  Ulib.Text.concat
    Ulib.Text.empty
    (List.map
       (fun c -> 
       if c=Ulib.UChar.of_char '_'  then r"T"     else
       if c=Ulib.UChar.of_char '#'  then r"H"     else
       if c=Ulib.UChar.of_char '\'' then r"P"     else
       if c=Ulib.UChar.of_char '0'  then r"Zero"  else
       if c=Ulib.UChar.of_char '1'  then r"One"   else
       if c=Ulib.UChar.of_char '2'  then r"Two"   else
       if c=Ulib.UChar.of_char '3'  then r"Three" else
       if c=Ulib.UChar.of_char '4'  then r"Four"  else
       if c=Ulib.UChar.of_char '5'  then r"Five"  else
       if c=Ulib.UChar.of_char '6'  then r"Six"   else
       if c=Ulib.UChar.of_char '7'  then r"Seven" else
       if c=Ulib.UChar.of_char '8'  then r"Eight" else
       if c=Ulib.UChar.of_char '9'  then r"Nine"  else
       Ulib.Text.of_uchar c)
       (Ulib.Text.explode rr))

let tex_command_name rr = r"\\" ^^ tex_command_prefix ^^ tex_command_escape rr 
let tex_command_label rr =  tex_label_prefix ^^ tex_command_escape rr 

(* escaping of Lem source identifiers to appear in LaTeX *)
let tex_escape rr = 
  Ulib.Text.concat
    Ulib.Text.empty
    (List.map
       (fun c ->  
         if c=Ulib.UChar.of_char '_'  then r"\\_" else 
         if c=Ulib.UChar.of_char '%'  then r"\\%" else 
         if c=Ulib.UChar.of_char '$'  then r"\\$" else 
         if c=Ulib.UChar.of_char '#'  then r"\\#" else 
         if c=Ulib.UChar.of_char '?'  then r"\\mbox{?}" else 
         if c=Ulib.UChar.of_char '^'  then r"\\mbox{$\\uparrow$}" else 
         if c=Ulib.UChar.of_char '{'  then r"\\{" else 
         if c=Ulib.UChar.of_char '}'  then r"\\}" else 
         if c=Ulib.UChar.of_char '<'  then r"\\mbox{$<$} " else 
         if c=Ulib.UChar.of_char '>'  then r"\\mbox{$>$} " else 
         if c=Ulib.UChar.of_char '&'  then r"\\&" else 
         if c=Ulib.UChar.of_char '\\' then r"\\mbox{$\\backslash{}$}" else 
         if c=Ulib.UChar.of_char '|'  then r"\\mbox{$\\mid$}" else 
         Ulib.Text.of_uchar c)
       (Ulib.Text.explode rr))

let tex_id_wrap = function
  | Term_const         -> r"\\" ^^ tex_sty_prefix ^^ r"TermConst"        
  | Term_ctor          -> r"\\" ^^ tex_sty_prefix ^^ r"TermCtor"         
  | Term_field         -> r"\\" ^^ tex_sty_prefix ^^ r"TermField"        
  | Term_method        -> r"\\" ^^ tex_sty_prefix ^^ r"TermMethod"       
  | Term_var           -> r"\\" ^^ tex_sty_prefix ^^ r"TermVar"          
  | Term_var_toplevel  -> r"\\" ^^ tex_sty_prefix ^^ r"TermVarToplevel" 
  | Term_spec          -> r"\\" ^^ tex_sty_prefix ^^ r"TermSpec"         
  | Type_ctor          -> r"\\" ^^ tex_sty_prefix ^^ r"TypeCtor"         
  | Type_var           -> r"\\" ^^ tex_sty_prefix ^^ r"TypeVar"          
  | Module_name        -> r"\\" ^^ tex_sty_prefix ^^ r"ModuleName"       
  | Class_name         -> r"\\" ^^ tex_sty_prefix ^^ r"ClassName"        
  | Target             -> r"\\" ^^ tex_sty_prefix ^^ r"Target"            
  | Nexpr_var          -> r"\\" ^^ tex_sty_prefix ^^ r"Nexpr_var"            

let split_suffix s =
  let regexp = Str.regexp "\\(.*[^'0-9]\\)\\([0-9]*\\)\\('*\\)\\(.*\\)" in
  if Str.string_match regexp s 0 then
    (Str.matched_group 1 s, 
     let (^) = Pervasives.(^) in
     let numeric_suffix = Str.matched_group 2 s in 
     let prime_suffix = Str.matched_group 3 s in
     let remaining_suffix = Str.matched_group 4 s in
     (if numeric_suffix = "" then "" 
     else if String.length numeric_suffix = 1 then "_" ^ numeric_suffix
     else "_{"^numeric_suffix^"}") ^
     prime_suffix ^
     remaining_suffix)       
  else
    raise (Failure "split_suffix")

let split_suffix_rope r = 
  let (s1,s2) = split_suffix (Ulib.Text.to_string r) in
  (Ulib.Text.of_string s1, Ulib.Text.of_string s2)

(* flatten into a list of Cons-free and Emp-free t *)
(* poor complexity *)
let flatten_to_list : t -> t list = 
  let rec f = function
    | Cons(o1,o2) -> f o1 @ f o2
    | Block(b, _, t) -> f t
    | Empty -> []
    | (_ as o1) -> [o1] in
  f

(* the Nl-separated lists of t, including start and end *)
(* poor complexity *)
let line_break : t list -> t list list  = 
  function os -> 
    let rec f acc1 acc2 os = 
      match os with 
      | [] -> acc2@[acc1]
      | Inter(Ast.Nl)::os' -> f [] (acc2@[acc1]) os'
      | o1::os' -> f (acc1@[o1]) acc2 os' in
    f [] [] os

let debug = false

let to_rope_ident a rr =
  let (r1,r2) = split_suffix_rope rr in
  tex_id_wrap a ^^ r"{" ^^ tex_escape r1 ^^ r"}" ^^ r2

let quote_char = r"\""

let rec to_rope_tex_single t = 
  match t with
  | Empty -> r""
  | Kwd(s) ->  Ulib.Text.of_latin1 s
  | Ident(a,r) -> to_rope_ident a r
  | Num(i) ->  Ulib.Text.of_latin1 (string_of_int i)
  | Inter(Ast.Com(rr)) -> r"\\tsholcomm{" ^^ tex_escape (ml_comment_to_rope rr)  ^^ r"}" 
  | Inter(Ast.Ws(rr)) -> rr
  | Inter(Ast.Nl) -> raise (Failure "Nl in to_rope_tex")
  | Str(s) ->  quote_string quote_char s
  | Err(s) -> raise (Backend(s))
  | Meta(s) -> Ulib.Text.of_latin1 s
  | Texspace -> r"\\ "   
  | Break_hint _ -> r""   
  | Ensure_newline -> r""   
  | Internalspace -> r""   
  | Cons(t1,t2) -> raise (Failure "Cons in to_rope_tex") 
  | Block _ -> raise (Failure "Block in to_rope_tex") 


let make_indent r = 
  let n = Ulib.Text.length r in
  let single_indent = "\\ " in
  let rec n_of x n = if n=0 then [] else x::n_of x (n-1) in
  Ulib.Text.of_string (String.concat "" (n_of single_indent n)) 

let strip_initial_and_final_texspace ts =
  let rec strip_initial_texspace ts = match ts with
  | [] -> [] 
  | Texspace :: ts' -> strip_initial_texspace ts'
  | _ :: ts' -> ts in
  List.rev (strip_initial_texspace (List.rev (strip_initial_texspace ts))) 
    

(* returns None if all whitespace or texspace, otherwise Some of the indented rope *)
let to_rope_option_line : t list -> Ulib.Text.t option 
    = function ts -> 
      let rec f indent_acc ts = 
        match ts with
        | [] -> None
        | Inter(Ast.Ws(r))::ts' -> f (indent_acc ^^ r) ts'
        | _ :: ts' when List.for_all (fun o1 -> o1=Texspace) ts ->
            None
        | _ :: ts' -> 
            Some ( make_indent indent_acc ^^ 
                   Ulib.Text.concat (r"") 
                     (List.map to_rope_tex_single 
                        (strip_initial_and_final_texspace ts))) in
      f (r"") ts 

let strip_initial_and_final_blank_lines tss =
  let rec strip_initial tss = match tss with
  | [] -> []
  | None::tss' -> strip_initial tss'
  | _ :: _ -> tss in
  let dummy_space tso = match tso with 
  | None -> r"\\ "  (* to workaround latex tabbing sensitivity *)
  | Some r -> r in
  List.map dummy_space (List.rev (strip_initial (List.rev (strip_initial tss)))) 

let rec to_rope_lines strip_blanks tss = 
  let rs = if strip_blanks then 
    strip_initial_and_final_blank_lines 
      (List.map to_rope_option_line tss)
  else
    List.map
      (function | None -> r"" | Some r -> r) 
      (List.map to_rope_option_line tss) in

  let rec f rs = 
    match rs with
    | [] -> r""
    | [rr] -> rr
    | rr :: rs' -> rr ^^ r"\\\\{}\n" ^^ f rs' in
  
  match rs with 
  | [] -> None
  | _ -> Some (f rs) 


let to_rope_option_tex term need_space strip_blanks t = 

  if debug then Printf.printf "\n\n\nto_rope_tex input:\n%s" (Ulib.Text.to_string (pp_raw_t t));

  let lines = line_break (flatten_to_list t) in
  
  let ro = to_rope_lines strip_blanks lines in
  
  (if debug then Printf.printf "\n\nto_rope_tex output:\n%s" (Ulib.Text.to_string (match ro with None -> r"None" | Some rr -> r"Some(" ^^ rr ^^ r")")));
  
  ro

