/** mermaid
 *  https://mermaidjs.github.io/
 *  (c) 2015 Knut Sveidqvist
 *  MIT license.
 */
%lex

%options case-insensitive

%x click
%x href
%x callbackname
%x callbackargs
%x open_directive
%x type_directive
%x arg_directive
%x close_directive
%x acc_title
%x acc_descr
%x acc_descr_multiline
%%
\%\%\{                                                          { this.begin('open_directive'); return 'open_directive'; }
<open_directive>((?:(?!\}\%\%)[^:.])*)                          { this.begin('type_directive'); return 'type_directive'; }
<type_directive>":"                                             { this.popState(); this.begin('arg_directive'); return ':'; }
<type_directive,arg_directive>\}\%\%                            { this.popState(); this.popState(); return 'close_directive'; }
<arg_directive>((?:(?!\}\%\%).|\n)*)                            return 'arg_directive';

accTitle\s*":"\s*                                               { this.begin("acc_title");return 'acc_title'; }
<acc_title>(?!\n|;|#)*[^\n]*                                    { this.popState(); return "acc_title_value"; }
accDescr\s*":"\s*                                               { this.begin("acc_descr");return 'acc_descr'; }
<acc_descr>(?!\n|;|#)*[^\n]*                                    { this.popState(); return "acc_descr_value"; }
accDescr\s*"{"\s*                                { this.begin("acc_descr_multiline");}
<acc_descr_multiline>[\}]                       { this.popState(); }
<acc_descr_multiline>[^\}]*                     return "acc_descr_multiline_value";

\%\%(?!\{)*[^\n]*                                               /* skip comments */
[^\}]\%\%*[^\n]*                                                /* skip comments */
\%\%*[^\n]*[\n]*           /* do nothing */

[\n]+                   return 'NL';
\s+                     /* skip whitespace */
\#[^\n]*                /* skip comments */
\%%[^\n]*               /* skip comments */

/*
---interactivity command---
'href' adds a link to the specified task. 'href' can only be specified when the
line was introduced with 'click'.
'href "<link>"' attaches the specified link to the task that was specified by 'click'.
*/
"href"[\s]+["]          this.begin("href");
<href>["]               this.popState();
<href>[^"]*             return 'href';

/*
---interactivity command---
'call' adds a callback to the specified task. 'call' can only be specified when
the line was introdcued with 'click'.
'call <callbackname>(<args>)' attaches the function 'callbackname' with the specified
arguments to the task that was specified by 'click'.
Function arguments are optional: 'call <callbackname>()' simply executes 'callbackname' without any arguments.
*/
"call"[\s]+             this.begin("callbackname");
<callbackname>\([\s]*\) this.popState();
<callbackname>\(        this.popState(); this.begin("callbackargs");
<callbackname>[^(]*     return 'callbackname';
<callbackargs>\)        this.popState();
<callbackargs>[^)]*     return 'callbackargs';

/*
'click' is the keyword to introduce a line that contains interactivity commands.
'click' must be followed by an existing task-id. All commands are attached to
that id.
'click <id>' can be followed by href or call commands in any desired order
*/
"click"[\s]+            this.begin("click");
<click>[\s\n]           this.popState();
<click>[^\s\n]*         return 'click';

"gantt"                     return 'gantt';
"dateFormat"\s[^#\n;]+      return 'dateFormat';
"inclusiveEndDates"         return 'inclusiveEndDates';
"topAxis"                   return 'topAxis';
"axisFormat"\s[^#\n;]+      return 'axisFormat';
"includes"\s[^#\n;]+        return 'includes';
"excludes"\s[^#\n;]+        return 'excludes';
"todayMarker"\s[^\n;]+      return 'todayMarker';
\d\d\d\d"-"\d\d"-"\d\d      return 'date';
"title"\s[^#\n;]+           return 'title';
"accDescription"\s[^#\n;]+  return 'accDescription'
"section"\s[^#:\n;]+        return 'section';
[^#:\n;]+                   return 'taskTxt';
":"[^#\n;]+                 return 'taskData';
":"                         return ':';
<<EOF>>                     return 'EOF';
.                           return 'INVALID';

/lex

%left '^'

%start start

%% /* language grammar */

start
	: directive start
	| gantt document 'EOF' { return $2; }
	;

document
	: /* empty */ { $$ = [] }
	| document line {$1.push($2);$$ = $1}
	;

line
	: SPACE statement { $$ = $2 }
	| statement { $$ = $1 }
	| NL { $$=[];}
	| EOF { $$=[];}
	;

statement
  : dateFormat {yy.setDateFormat($1.substr(11));$$=$1.substr(11);}
  | inclusiveEndDates {yy.enableInclusiveEndDates();$$=$1.substr(18);}
  | topAxis {yy.TopAxis();$$=$1.substr(8);}
  | axisFormat {yy.setAxisFormat($1.substr(11));$$=$1.substr(11);}
  | excludes {yy.setExcludes($1.substr(9));$$=$1.substr(9);}
  | includes {yy.setIncludes($1.substr(9));$$=$1.substr(9);}
  | todayMarker {yy.setTodayMarker($1.substr(12));$$=$1.substr(12);}
  | title {yy.setAccTitle($1.substr(6));$$=$1.substr(6);}
  | acc_title acc_title_value  { $$=$2.trim();yy.setAccTitle($$); }
  | acc_descr acc_descr_value  { $$=$2.trim();yy.setAccDescription($$); }
  | acc_descr_multiline_value { $$=$1.trim();yy.setAccDescription($$); }  | section {yy.addSection($1.substr(8));$$=$1.substr(8);}
  | clickStatement
  | taskTxt taskData {yy.addTask($1,$2);$$='task';}
  | directive
  ;

directive
    : openDirective typeDirective closeDirective 'NL'
    | openDirective typeDirective ':' argDirective closeDirective 'NL'
    ;

/*
click allows any combination of href and call.
*/
clickStatement
    : click callbackname                    {$$ = $1;yy.setClickEvent($1, $2, null);}
    | click callbackname callbackargs       {$$ = $1;yy.setClickEvent($1, $2, $3);}

    | click callbackname href               {$$ = $1;yy.setClickEvent($1, $2, null);yy.setLink($1,$3);}
    | click callbackname callbackargs href  {$$ = $1;yy.setClickEvent($1, $2, $3);yy.setLink($1,$4);}

    | click href callbackname               {$$ = $1;yy.setClickEvent($1, $3, null);yy.setLink($1,$2);}
    | click href callbackname callbackargs  {$$ = $1;yy.setClickEvent($1, $3, $4);yy.setLink($1,$2);}

    | click href                            {$$ = $1;yy.setLink($1, $2);}
    ;

clickStatementDebug
    : click callbackname                    {$$=$1 + ' ' + $2;}
    | click callbackname href               {$$=$1 + ' ' + $2 + ' ' + $3;}

    | click callbackname callbackargs       {$$=$1 + ' ' + $2 + ' ' + $3;}
    | click callbackname callbackargs href  {$$=$1 + ' ' + $2 + ' ' + $3 + ' ' + $4;}

    | click href callbackname               {$$=$1 + ' ' + $2 + ' ' + $3;}
    | click href callbackname callbackargs  {$$=$1 + ' ' + $2 + ' ' + $3 + ' ' + $4;}

    | click href                            {$$=$1 + ' ' + $2;}
    ;

openDirective
  : open_directive { yy.parseDirective('%%{', 'open_directive'); }
  ;

typeDirective
  : type_directive { yy.parseDirective($1, 'type_directive'); }
  ;

argDirective
  : arg_directive { $1 = $1.trim().replace(/'/g, '"'); yy.parseDirective($1, 'arg_directive'); }
  ;

closeDirective
  : close_directive { yy.parseDirective('}%%', 'close_directive', 'gantt'); }
  ;

%%
