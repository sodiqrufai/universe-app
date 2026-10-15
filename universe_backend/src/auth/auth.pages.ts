// Self-contained HTML pages served by the backend for the links Supabase
// emails to students (confirm email, reset password). Served from the same
// origin as the API, so no extra hosting is needed.

const shell = (title: string, body: string, script = '') => `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<title>${title} · UniVerse</title>
<style>
:root{--p:#4F2CCF;--p2:#6D4AFF;--lp:#F0ECFF;--bg:#FAFAFC;--t:#15152A;--ts:#6F7080;--b:#E8E8F0;--ok:#2E9B62;--err:#D9534F}
*{box-sizing:border-box}body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:var(--bg);font-family:-apple-system,"Segoe UI",Roboto,Poppins,sans-serif;color:var(--t);padding:16px}
.card{background:#fff;border:1px solid var(--b);border-radius:20px;box-shadow:0 4px 24px rgba(79,44,207,.08);padding:32px 24px;width:100%;max-width:420px;text-align:center}
.brand{font-weight:800;font-size:22px;background:linear-gradient(90deg,#1E4FC4,#7B2FBF);-webkit-background-clip:text;background-clip:text;color:transparent;margin-bottom:20px}
.icon{width:64px;height:64px;border-radius:50%;margin:0 auto 16px;display:flex;align-items:center;justify-content:center;font-size:30px;background:var(--lp);color:var(--p)}
.icon.ok{background:#E6F5EC;color:var(--ok)}.icon.err{background:#FBEAE9;color:var(--err)}
h1{font-size:22px;margin:0 0 8px}p{color:var(--ts);font-size:14px;line-height:1.5;margin:0 0 16px}
label{display:block;text-align:left;font-size:13px;font-weight:600;margin:12px 0 6px}
input{width:100%;padding:12px 14px;border:1px solid var(--b);border-radius:12px;font-size:16px;outline:none}input:focus{border-color:var(--p2);box-shadow:0 0 0 3px var(--lp)}
button{width:100%;margin-top:20px;padding:14px;border:0;border-radius:12px;background:var(--p);color:#fff;font-size:16px;font-weight:600;cursor:pointer}button:disabled{opacity:.6;cursor:default}
.msg{font-size:13px;margin-top:12px;min-height:18px}.msg.err{color:var(--err)}.hint{font-size:12px;color:var(--ts);margin-top:16px}
</style></head><body><main class="card"><div class="brand">UniVerse</div>${body}</main>${script}</body></html>`;

export const confirmedPage = () =>
  shell(
    'Email confirmed',
    `<div id="ok"><div class="icon ok">✓</div><h1>Email confirmed</h1>
<p>Your UniVerse account is verified. Go back to the app and log in to finish setting up your profile.</p></div>
<div id="bad" style="display:none"><div class="icon err">!</div><h1>Link expired</h1>
<p id="why">This confirmation link is invalid or has expired. Open UniVerse, try to log in, and tap “Resend confirmation email”.</p></div>
<div class="hint">You can close this tab.</div>`,
    `<script>
var h=new URLSearchParams(location.hash.replace(/^#/,''));
if(h.get('error')||h.get('error_code')){document.getElementById('ok').style.display='none';document.getElementById('bad').style.display='block';}
</script>`,
  );

export const resetPasswordPage = () =>
  shell(
    'Reset password',
    `<div id="form"><div class="icon">🔒</div><h1>Choose a new password</h1>
<p>Use at least 8 characters.</p>
<label for="p1">New password</label><input id="p1" type="password" autocomplete="new-password" minlength="8">
<label for="p2">Confirm password</label><input id="p2" type="password" autocomplete="new-password" minlength="8">
<button id="go">Update password</button><div id="msg" class="msg"></div></div>
<div id="done" style="display:none"><div class="icon ok">✓</div><h1>Password updated</h1>
<p>Go back to the UniVerse app and log in with your new password.</p></div>
<div id="bad" style="display:none"><div class="icon err">!</div><h1>Link expired</h1>
<p>This reset link is invalid or has expired. Open UniVerse and request a new one from “Forgot Password?”.</p></div>`,
    `<script>
var h=new URLSearchParams(location.hash.replace(/^#/,''));
var token=h.get('access_token');
function show(id){['form','done','bad'].forEach(function(x){document.getElementById(x).style.display=x===id?'block':'none'})}
if(!token||h.get('error')){show('bad')}
var msg=document.getElementById('msg'),btn=document.getElementById('go');
btn.onclick=async function(){
  var a=document.getElementById('p1').value,b=document.getElementById('p2').value;
  msg.className='msg err';
  if(a.length<8){msg.textContent='Password must be at least 8 characters.';return}
  if(a!==b){msg.textContent='Passwords do not match.';return}
  btn.disabled=true;msg.className='msg';msg.textContent='Updating…';
  try{
    var r=await fetch('/auth/update-password',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({accessToken:token,newPassword:a})});
    var d=await r.json();
    if(d.success){history.replaceState(null,'',location.pathname);show('done')}
    else{msg.className='msg err';msg.textContent=d.error||'Could not update password.';btn.disabled=false}
  }catch(e){msg.className='msg err';msg.textContent='Could not connect. Try again.';btn.disabled=false}
};
</script>`,
  );
