/* Écran « Accès » (administrateur) : comptes du bureau. */
(function(){
  if(typeof VIEWS==="undefined")return;
  SUBVIEWS.push("acces");
  const plusShell=VIEWS.plus.shell;
  VIEWS.plus.shell=()=>{const h=plusShell();if(!S.isAdmin)return h;
    return h.replace('<a class="row" href="#sauvegarde"','<a class="row" href="#acces" style="text-decoration:none;color:inherit"><div class="main"><b>Accès à l\'appli</b><small>Créer un compte · mot de passe · retirer un accès</small></div><div class="right">›</div></a><a class="row" href="#sauvegarde"');};

  async function appel(body){
    const {data,error}=await S.sb.functions.invoke("acces",{body});
    if(error){let m=error.message;try{const j=await error.context.json();if(j&&j.error)m=j.error;}catch(e){}throw new Error(m);}
    if(data&&data.error)throw new Error(data.error);
    return data;
  }
  function motDePasse(){const a="abcdefghjkmnpqrstuvwxyz23456789",v=crypto.getRandomValues(new Uint32Array(12));let s="";for(let i=0;i<12;i++){s+=a[v[i]%a.length];if(i===3||i===7)s+="-";}return s;}
  const URL_APPLI=location.origin+location.pathname;
  function montrerMdp(titre,email,mdp){
    const sms=`Bonjour, voici ton accès à l'appli de l'Amicale : ${URL_APPLI}\nIdentifiant : ${email}\nMot de passe provisoire : ${mdp}\nChange-le après ta première connexion (Compte › Changer mon mot de passe).`;
    openSheet(titre,`<div class="card"><p style="margin-top:0">Transmettez ces informations à la personne (de vive voix ou par SMS). Le mot de passe ne sera plus affiché ensuite.</p>
      <label class="f"><span>Identifiant</span><input readonly value="${esc(email)}"></label>
      <label class="f"><span>Mot de passe provisoire</span><input readonly class="mono" value="${esc(mdp)}"></label></div>
      <div class="btns"><button class="btn gold" id="cpS">Copier le message</button>${""}<a class="btn sec" href="sms:?&body=${encodeURIComponent(sms)}">Envoyer par SMS</a></div>
      <button class="btn sec full" data-close>Terminé</button>`,p=>{$("#cpS",p).onclick=()=>copy(sms);});
  }

  VIEWS.acces={
    shell:()=>`<a class="back" href="#plus">‹ Plus</a>${intro("Le bureau","Accès à l'appli","Qui peut se connecter, et avec quel rôle.")}
      <button class="btn gold full" id="aNew">+ Nouvel accès</button><div id="aL" style="margin-top:12px"><div class="empty">Chargement…</div></div>
      <p class="note">Caissier : encaisser, créer des adhérents, signaler une erreur. Administrateur : tout.</p>`,
    bind(){$("#aNew").onclick=nouveau;charger();},
  };
  let comptes=[];
  async function charger(){
    try{comptes=(await appel({action:"liste"})).comptes;}catch(e){$("#aL").innerHTML=`<div class="banner">Impossible de lire les accès : ${esc(e.message)}</div>`;return;}
    comptes.sort((a,b)=>((a.profil&&a.profil.nom)||a.email).localeCompare((b.profil&&b.profil.nom)||b.email,"fr"));
    $("#aL").innerHTML=`<div class="list">${comptes.map(c=>{const p=c.profil,off=!p||p.actif===false;return`<div class="row" data-a="${esc(c.id)}"><div class="av">${esc(p?p.initiales:"?")}</div><div class="main"><b>${esc(p?p.nom:c.email)}${c.id===S.uid?" (vous)":""}</b><small>${esc(c.email)}${c.derniere?" · vu le "+fd(String(c.derniere).slice(0,10)):" · jamais connecté"}</small></div><div class="right">${off?'<span class="chip bad">'+(p?"Retiré":"Sans rôle")+'</span>':`<span class="chip ${p.role==="admin"?"ok":""}">${p.role==="admin"?"Admin":"Caissier"}</span>`}</div></div>`;}).join("")}</div>`;
    $$("[data-a]").forEach(r=>r.onclick=()=>fiche(comptes.find(c=>c.id===r.dataset.a)));
  }
  function fiche(c){
    const p=c.profil,off=!p||p.actif===false,moi=c.id===S.uid;
    if(!p)return toast("Compte sans rôle : créez-le depuis « Nouvel accès » avec un autre mail, ou contactez le support.");
    openSheet(p.nom,`<div class="card"><p style="margin:0">${esc(c.email)}<br>${off?"Accès retiré":(p.role==="admin"?"Administrateur":"Caissier")} · initiales ${esc(p.initiales)}</p></div>
      ${off?`<button class="btn gold full" id="fR">Rétablir l'accès</button>`:`
      <div class="btns"><button class="btn" id="fM">Nouveau mot de passe</button></div>
      ${moi?"":`<label class="f"><span>Rôle</span><select id="fRole"><option value="caissier" ${p.role==="caissier"?"selected":""}>Caissier</option><option value="admin" ${p.role==="admin"?"selected":""}>Administrateur</option></select></label>
      <div class="btns"><button class="btn danger" id="fX">Retirer l'accès</button></div>`}`}`,q=>{
      const run=async(body,ok)=>{try{await appel(body);toast(ok);closeSheet();charger();reload();}catch(e){toast(e.message);}};
      const r=$("#fR",q);if(r)r.onclick=()=>run({action:"retablir",id:c.id},"Accès rétabli");
      const m=$("#fM",q);if(m)m.onclick=async()=>{const mdp=motDePasse();try{await appel({action:"mdp",id:c.id,motdepasse:mdp});montrerMdp("Nouveau mot de passe",c.email,mdp);}catch(e){toast(e.message);}};
      const ro=$("#fRole",q);if(ro)ro.onchange=()=>run({action:"role",id:c.id,role:ro.value},"Rôle modifié");
      const x=$("#fX",q);if(x)x.onclick=async()=>{if(await confirmBox(`Retirer l'accès de ${p.nom} ? Il ne pourra plus se connecter. Ses encaissements restent dans l'historique.`,"Retirer"))run({action:"retirer",id:c.id},"Accès retiré");};
    });
  }
  function nouveau(){
    openSheet("Nouvel accès",`<div class="card">
      <label class="f"><span>Prénom et nom <i>*</i></span><input id="nN" placeholder="Patrick Couttet" autocapitalize="words"></label>
      <div class="two"><label class="f"><span>Initiales <i>*</i></span><input id="nI" maxlength="4" autocapitalize="characters" placeholder="PC"></label>
      <label class="f"><span>Rôle</span><select id="nR"><option value="caissier">Caissier</option><option value="admin">Administrateur</option></select></label></div>
      <label class="f"><span>Adresse mail (identifiant) <i>*</i></span><input id="nE" type="email" autocapitalize="off"></label></div>
      <p class="note">Un mot de passe provisoire sera créé et affiché pour que vous le transmettiez.</p>
      <button class="btn gold full" id="nOk">Créer l'accès</button>`,q=>{
      const ini=()=>{const w=$("#nN",q).value.trim().split(/\s+/).filter(Boolean);if(!$("#nI",q).dataset.touche)$("#nI",q).value=w.length>1?(noAcc(w[0])[0]+noAcc(w[w.length-1])[0]).toUpperCase():"";};
      $("#nN",q).oninput=ini;$("#nI",q).oninput=e=>{e.target.dataset.touche=1;e.target.value=noAcc(e.target.value).toUpperCase().replace(/[^A-Z]/g,"");};
      $("#nOk",q).onclick=async()=>{
        const body={action:"creer",nom:$("#nN",q).value.trim(),initiales:$("#nI",q).value.trim(),role:$("#nR",q).value,email:$("#nE",q).value.trim().toLowerCase(),motdepasse:motDePasse()};
        if(!body.nom)return toast("Indiquez le nom");if(!/^[A-Z]{2,4}$/.test(body.initiales))return toast("Initiales : 2 à 4 lettres");if(!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(body.email))return toast("Adresse mail invalide");
        $("#nOk",q).disabled=true;
        try{await appel(body);charger();reload();montrerMdp("Accès créé",body.email,body.motdepasse);}catch(e){$("#nOk",q).disabled=false;toast(e.message);}
      };
    });
  }
  if(S.view==="plus"||location.hash==="#acces")setTimeout(go,0);
})();
