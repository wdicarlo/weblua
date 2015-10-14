#!/usr/bin/env wsapi.cgi

require "orbit"
require "markdown"
require "cosmo"

module("weblua", package.seeall, orbit.new)

string.concat = function (...)
   local result = {}
   for str in ipairs(...) do
      result[#result+1] = str
   end
   return table.concat(result)
end

function url_decode(str)
   str = string.gsub (str, "+", " ")
   str = string.gsub (str, "%%(%x%x)",
   function(h) return string.char(tonumber(h,16)) end)
   str = string.gsub (str, "\r\n", "\n")
   return str
end
function load(str,name,mode,env)
   local chunk,err = loadstring(str,name)
   if chunk then setfenv(chunk,env) end
   return chunk,err
end

local print_buff,term_print_installed

function term_print(...)
    local args,n = {...},select('#',...)
    for i = 1,n do
        args[i] = tostring(args[i])
    end
    table.insert(print_buff,table.concat(args,'   '))
end

local env = {
    print = term_print,
}
setmetatable(env,{ __index = _G, __newindex = _G})


function eval(code)
    local status,val,f,err,rcnt
    print_buff = {}
    --code,rcnt = code:gsub('^%s*=','return ')
    f,err = load(code,'TMP','t',env)
    if f then
        status,val = pcall(f)
        if not status then err = val
        else
            if val == nil then 
               val = "" 
            end
            if #print_buff > 0 then val = table.concat(print_buff,'\n') end
            return tostring(val)
        end
    end
    if err then
       local ender = "'<eof>'"
       err = tostring(err):gsub('^%[string "TMP"%]:[0-9]+:','')
       if string.sub(err, -#ender) == ender then
          return "continued"
       end

       return err
    end
end
function render_terminal (web, args)
    return 
    [[    
        <!DOCTYPE html>
          <head>
            <meta charset="utf-8">
	      <script type='text/javascript' src="/static/js/jquery-2.1.3.min.js"></script>
	      <script type='text/javascript' src="/static/js/jqconsole.js"> </script>
            </head> 
            <link rel="stylesheet" type="text/css" href="/static/css/bootstrap.min.css" media="screen">
                
            <body class="theme-default page-500" style="background: rgb(0, 0, 0) !important;">
              <div id="console">
                 <!-- CONTENT -->
		    <script>
		    $(document).ready(function () {
		    var LINE_LIMIT = 100;
		    var jqconsole = $('#console').jqconsole('Lua Console is Ready!!!\n','> ');
		    var promptText = ''
		    var prompt = function () {
		       jqconsole.Prompt(true, function (input) {

			  // Output input with the class jqconsole-output.
			  promptText = promptText + ' ' + input
			  $.ajax({
				    //data: { code : promptText }, url: '/eval',
				    //data: { code : promptText }, url: '/weblua.ws/eval',
				    data: { code : promptText }, url: ']].. web:link('/eval')..[[',
				    success: function (msg) {
					 jqconsole.SetPromptLabel('> ')
					 if( msg.length > 0 ) {
					    if( msg == 'continued' ) {
					       jqconsole.SetPromptLabel('>> ')
					    } else {
					       jqconsole.Write( msg + '\n', 'jqconsole-output');
					       promptText = ''
					    }
					 }
					 prompt();
				    },
				    error: function (msg) { 
					 jqconsole.Write( 'failed!' + '\n', 'jqconsole-output');
					 prompt();
				    },
				    async: false,
				    timeout: 10000,
				});
		       });
		    };
		    prompt();
		    });
		    </script> 
		    <style>
		       html, body {
			  background-color: #fff;
			  color: black;
			  font-family: monospace;
		       }
		       /* The console container element */
		       #console {
			  clear:both;  
			  color: black; 
			  width: auto; 
			  height: 350px; 
			  text-align: left; 
			  padding: 10px;
			  background-color:black;
		       }
		       /* The inner console element. */
		       .jqconsole {
			  padding: 10px;
		       }
		       /* The cursor. */
		       .jqconsole-cursor {
			  background-color: gray;
		       }
		       /* The cursor color when the console looses focus. */
		       .jqconsole-blurred .jqconsole-cursor {
			  background-color: gray;
		       }
		       /* The current prompt text color */
		       .jqconsole-prompt {
			  color: black;
		       }
		       /* The command history */
		       .jqconsole-old-prompt {
			  color: gray;
			  font-weight: normal;
		       }
		       /* The text color when in input mode. */
		       .jqconsole-input {
			  color: blue;
		       }
		       /* Previously entered input. */
		       .jqconsole-old-input {
			  color: blue;
			  font-weight: normal;
		       }
		       /* The text color of the output. */
		       .jqconsole-output {
			  color: black;
		       }
		    </style>
                 </div>
            </body>
        </html>
        ]]
end



function render_eval(web)
   local code = ""
   local func 
   local result = ""

   if web.GET.code then
      return eval(web.GET.code)
   end

   return result
end

function terminal_get(web)
   return render_terminal(web, web.input)
end

function eval_get(web)
   return render_eval(web)
end
weblua:dispatch_get(terminal_get,"/terminal")
weblua:dispatch_get(eval_get,"/eval")


function index(web)
   return render_terminal(web, web.input)
end

function code_reload_get(web)
   local reloaded = "Reloaded lua scripts:"
   for k, v in pairs (_G.package.loaded) do
      if v== true then
         reloaded = reloaded .. " <br/>" .. k
         _G.package.loaded[k] = nil
      end
    end
   require "src.weblua"
   return reloaded
end


weblua:dispatch_get(index, "/", "/index")
weblua:dispatch_get(code_reload_get,"/code_reload")


orbit.htmlify(weblua, "layout", "_.+", "render_.+")
