"vim: ts=4 nowrap

" ---------------------------------------------------------------------
" GetLatestVimScripts.vim
"  Author:		Charles E. Campbell, Jr.
"  Last Change: Aug 20, 2004
"  Version:		11
"  Usage:
"		vim GetLatestVimScripts.vim
"		:so %
" ---------------------------------------------------------------------
" Initialization:	{{{1
" if you're sourcing this file, surely you can't be
" expecting vim to be in its vi-compatible mode
set nocp
let s:save_cpo= &cpo
set cpo&vim

if exists("loaded_GetLatestVimScripts")
 finish
endif
let loaded_GetLatestVimScripts= 1

" insure that wget is executable
if executable("wget") != 1
 echoerr "GetLatestVimScripts needs wget which apparently is not available on your system"
 finish
endif

" ---------------------------------------------------------------------
"  Public Interface: {{{1
com! -nargs=0 GetLatestVimScripts call <SID>GetLatestVimScripts()

" ---------------------------------------------------------------------
"  GetOneScript: (Get Latest Vim Script) this function operates {{{1
"    on the current line, interpreting two numbers and text as
"    ScriptID, SourceID, and Filename.
"    It downloads any scripts that have newer versions from vim.sf.net.
fun! <SID>GetOneScript(...)
"   call Dfunc("GetOneScript()")

 " set options to allow progress to be shown on screen
  let t_ti= &t_ti
  let t_te= &t_te
  let rs  = &rs
  set t_ti= t_te= nors

 " put current line on top-of-screen and interpret it into
 " a      script identifer  : used to obtain webpage
 "        source identifier : used to identify current version
 " and an associated comment: used to report on what's being considered
  if a:0 >= 3
   let scriptid = a:1
   let srcid    = a:2
   let cmmnt    = a:3
  else
   let curline  = getline(".")
   let parsepat = '^\s*\(\d\+\)\s\+\(\d\+\)\s\+\(.\{-}\)$'
   let scriptid = substitute(curline,parsepat,'\1','')
   let srcid    = substitute(curline,parsepat,'\2','')
   let cmmnt    = substitute(curline,parsepat,'\3','')
  endif
  exe "norm z\<CR>"
  redraw!
  echomsg 'considering <'.cmmnt.'> scriptid='.scriptid.' srcid='.srcid

  " grab a copy of the plugin's vim.sf.net webpage
  let scriptaddr = 'http://vim.sf.net/script.php?script_id='.scriptid
  let tmpfile    = tempname()
  let v:errmsg   = ""

  " make three tries at downloading the description
  let itry       = 1
  while itry <= 3
"   	call Decho("try ".itry." to download description of <".tmpfile."> with addr=".scriptaddr)
  	if has("win32") || has("win16") || has("win95")
"     call Decho("wget -q -O ".tmpfile.' "'.scriptaddr.'"')
    exe "silent !wget -q -O ".tmpfile.' "'.scriptaddr.'"'
	else
"     call Decho("wget -q -O ".tmpfile." '".scriptaddr."'")
    exe "silent !wget -q -O ".tmpfile." '".scriptaddr."'"
	endif
	if itry == 1
    exe "silent vsplit ".tmpfile
	else
	 silent! e %
	endif
   silent! 1
   let v:errmsg= ""
  
   " find the latest source-id in the plugin's webpage
   silent! /Click on the package to download/
	if v:errmsg == ""
	 break
	endif
	let itry= itry + 1
  endwhile

  " test if finding /Click on the package.../ failed
  if v:errmsg != ""
   " restore options
	let &t_ti= t_ti
	let &t_te= t_te
	let &rs  = rs
  	echoerr "***error*** couldn'".'t find "Click on the package..." in description page for <'.cmmnt.">"
"	call Dret("GetOneScript : srch for /Click on the package/ failed")
  	return
  endif

  silent /src_id=/
  if v:errmsg != ""
   " restore options
	let &t_ti= t_ti
	let &t_te= t_te
	let &rs  = rs
  	echoerr "***error*** couldn'".'t find "src_id=" in description page for <'.cmmnt.">"
"	call Dret("GetOneScript : srch for /src_id/ failed")
  	return
  endif
  let srcidpat   = '^\s*<td class.*src_id=\(\d\+\)">\([^<]\+\)<.*$'
  let latestsrcid= substitute(getline("."),srcidpat,'\1','')
  let fname      = substitute(getline("."),srcidpat,'\2','')
"   call Decho("srcidpat<".srcidpat."> latestsrcid<".latestsrcid."> fname<".fname.">")
  silent q!
  call delete(tmpfile)

  " convert the strings-of-numbers into numbers
  let srcid       = srcid       + 0
  let latestsrcid = latestsrcid + 0
"   call Decho("srcid=".srcid." latestsrcid=".latestsrcid." fname<".fname.">")

  " has the plugin's most-recent srcid increased, which indicates
  " that it has been updated
  if latestsrcid > srcid
  	let s:downloads= s:downloads + 1
	if fname == bufname("%")
	 " GetOneScript has to be careful about downloading itself
	 let fname= "NEW_".fname
	endif

	" the plugin has been updated since we last obtained it,
	" so download a new copy
"	call Decho("...downloading new <".fname.">")
   echomsg "...downloading new <".fname.">"
  	if has("win32") || has("win16") || has("win95")
"     call Decho("wget -q -O ".fname.' "'.'http://vim.sf.net/scripts/download_script.php?src_id='.latestsrcid.'"')
    exe "silent !wget -q -O ".fname.' "'.'http://vim.sf.net/scripts/download_script.php?src_id='.latestsrcid.'"'
	else
"     call Decho("wget -q -O ".fname." '".'http://vim.sf.net/scripts/download_script.php?src_id='.latestsrcid."'")
    exe "silent !wget -q -O ".fname." '".'http://vim.sf.net/scripts/download_script.php?src_id='.latestsrcid."'"
	endif
   let modline=scriptid." ".latestsrcid." ".cmmnt
   call setline(line("."),modline)
"	call Decho("modline<".modline.">")
  endif

 " restore options
  let &t_ti= t_ti
  let &t_te= t_te
  let &rs  = rs
"   call Dret("GetOneScript")
endfun

" ---------------------------------------------------------------------
" GetLatestVimScripts: this function gets the latest versions of {{{1
" scripts based on the list in
"
"   (first dir in runtimepath)/GetLatest/GetLatestVimScripts.dat
fun! <SID>GetLatestVimScripts()
"  call Dfunc("GetLatestVimScripts()")

  " Find the .../GetLatest sudirectory under the runtimepath
  let rtplist= &rtp
  while rtplist != ""
   let datadir= substitute(rtplist,',.*$','','e')."/GetLatest"
   if isdirectory(datadir)
    break
   endif
   unlet datadir
   if rtplist =~ ','
    let rtplist= substitute(rtplist,'^.\{-},','','e')
   else
   	let rtplist= ""
   endif
  endwhile

  " Sanity checks: readability and writability
  if !exists("datadir")
   echoerr "Unable to find a GetLatest subdirectory on your runtimepath"
"   call Dret("GetLatestVimScripts : unable to find a GetLatest subdirectory")
   return
  endif
  if filewritable(datadir) != 2
   echoerr "Your ".datadir." isn't writable"
"   call Dret("GetLatestVimScripts : non-writable directory<".datadir.">")
   return
  endif
  let datafile= datadir."/GetLatestVimScripts.dat"
  if !filereadable(datafile)
   echoerr "Your data file<".datafile."> isn't readable"
"   call Dret("GetLatestVimScripts : non-readable datafile<".datafile.">")
   return
  endif
  if !filewritable(datafile)
   echoerr "Your data file<".datafile."> isn't writable"
"   call Dret("GetLatestVimScripts : non-writable datafile<".datafile.">")
   return
  endif
"  call Decho("datadir  <".datadir.">")
"  call Decho("datafile <".datafile.">")

  " don't let any events interfere (like winmanager's, taglist's, etc)
  let eikeep= &ei
  set ei=all

  " record current directory, change to datadir, open split window with
  " datafile
  let origdir= getcwd()
  exe "cd ".escape(substitute(datadir,'\','/','ge'),"|[]*'\" #")
  split
  exe "e ".escape(substitute(datafile,'\','/','ge'),"|[]*'\" #")
  res 1000
  let s:downloads= 0

  " Check on dependencies mentioned in plugins
"  call Decho("searching plugins for GetLatestVimScripts dependencies")
  let lastline    = line("$")
  let plugins     = globpath(&rtp,"plugin/*.vim")
  let foundscript = 0
"  call Decho("plugins<".plugins.">")
  while plugins != ""
   let plugin = substitute(plugins,'\n.*$','','e')
   let plugins= (plugins =~ '\n')? substitute(plugins,'^.\{-}\n\(.*\)$','\1','e') : ""
"   call Decho("dependency checking<".plugin.">")
   $
   exe "silent r ".plugin
   while search('^"\s\+GetLatestVimScripts:\s\+\d\+\s\+\d\+','W') != 0
    let newscript= substitute(getline("."),'^"\s\+GetLatestVimScripts:\s\+\d\+\s\+\d\+\s\+\(.*\)$','\1','e')
	if newscript !~ '^"'
	 " found a GetLatestVimScripts line, check if its already in the datafile
	 let curline = line(".")
	 if search('\<'.newscript.'\>','bW') == 0
	  " found a new script to permanently include in the datafile
"	  call Decho("append <".newscript."> to GetLatestVimScripts.dat")
	  let keep_rega   = @a
	  let @a          = substitute(getline("."),'^"\s\+GetLatestVimScripts:\s\+','','')
	  exe lastline."put a"
	  echomsg "Appending <".@a."> to ".datafile." for ".newscript
	  let @a          = keep_rega
	  let lastline    = lastline + 1
	  let curline     = curline + 1
	  let foundscript = foundscript + 1
"	 else	" Decho
"	  call Decho("found <".newscript."> (already in datafile)")
	 endif
	 let curline = curline + 1
	 exe curline
	endif
   endwhile
   let llp1 = lastline+1
   exe "silent! ".llp1.",$d"
  endwhile
  if foundscript == 0
   set nomod
  endif
  return

  " Check on out-of-date scripts using GetLatest/GetLatestVimScripts.dat
  set lz
"  call Decho("call GetOneScript on lines at end of datafile<".datafile.">")
  /^-----/,$g/^\s*\d/call <SID>GetOneScript()

  " Final report (an echomsg)
  silent ?^-------?
  exe "norm! kz\<CR>"
  if s:downloads == 1
   wq
   echomsg "Downloaded one updated script to <".datadir.">"
  elseif s:downloads == 2
   wq
   echomsg "Downloaded two updated scripts to <".datadir.">"
  elseif s:downloads > 1
   wq
   echomsg "Downloaded ".s:downloads." updated scripts to <".datadir.">"
  else
   q
   echomsg "Everything was already current"
  endif

  " restore events and current directory
  exe "cd ".escape(substitute(origdir,'\','/','ge'),"|[]*'\" #")
  let &ei= eikeep
  set nolz
"  call Dret("GetLatestVimScripts : did ".s:downloads." downloads")
endfun
" ---------------------------------------------------------------------

" Restore Options: {{{1
let &cpo= s:save_cpo

" vim: ts=4 fdm=marker
