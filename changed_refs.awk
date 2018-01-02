# Tests
## Restore

BEGIN {
  local_refs_prefix = "refs/remotes/";
  remote_refs_prefix = "refs/heads/";
  
  remote_1 = origin_1;
  remote_2 = origin_2;
  local_1 = prefix_1;
  local_2 = prefix_2;

  tty_attached = "/dev/tty";

  tty_dbg("AWK debugging is ON");
}
BEGINFILE {
  file_states();
}
{
  if($2){
    common_key();

    refs[$3][dest]["sha"] = $1;
    refs[$3][dest]["ref"] = $2;
  }
}
END {
  dest = "";
  origin = "";
  
  # Action array variables.
  split("", a_ff1); split("", a_ff2);
  split("", a_del1); split("", a_del2);
  split("", a_restore);
  split("", a_f1); split("", a_f2);
  split("", a_solv);
  # Operation array variables.
  split("", op_push_ff1); split("", op_push_ff2);
  split("", op_push1); split("", op_push2);
  split("", op_fetch1); split("", op_fetch2);
  split("", op_del_local);
  split("", op_solv_push1); split("", op_solv_push2);
  split("", op_solv_fetch1); split("", op_solv_fetch2);
  # Output variables.
  out_push1; out_push2;
  out_fetch1; out_fetch2;
  out_del;
  out_solv_push1; out_solv_push2;
  out_solv_fetch1; out_solv_fetch2;
}
END {
  generate_missing_refs();
  
  deletion_allowed = 0;
  unlock_deletion( \
    refs[must_exist_branch][remote_1]["sha"], \
    refs[must_exist_branch][remote_2]["sha"], \
    refs[must_exist_branch][local_1]["sha"], \
    refs[must_exist_branch][local_2]["sha"] \
  );
  tty_dbg("deletion allowance = " deletion_allowed " by " must_exist_branch);
  
  for(currentRef in refs){
    assign_action( \
      currentRef, \
      refs[currentRef][remote_1]["sha"], \
      refs[currentRef][remote_2]["sha"], \
      refs[currentRef][local_1]["sha"], \
      refs[currentRef][local_2]["sha"] \
    );
  }
  actions_to_operations();
  output_operations();
}

function assign_action(cr, rr1, rr2, lr1, lr2,    lr, rr){
  if(rr1 == rr2 && lr1 == lr2 && lr1 == rr2){
    # Nothing to change.
    return;
  }
  if(!(rr1 rr2)){
    tty_dbg("a_restore, no remote refs: " cr);
    a_restore[cr];
    return;
  }
  if(rr1 == rr2){
    rr = rr1;
    
    if(lr1 != rr){
      tty_dbg("a_f1, net fail: " cr);
      a_f1[cr];
    }
    if(lr2 != rr){
      tty_dbg("a_f2, net fail: " cr);
      a_f2[cr];
    }
    return;
  }

  if(!(lr1 lr2)){
    tty_dbg("a_solv, no local: " cr);
    a_solv[cr];
    return;
  }

  if(lr1 == lr2){
    lr = lr1;
    
    if(!rr1 && rr2 == lr){
      tty_dbg("a_del2: " cr);
      a_del2[cr];
      return;
    }
    if(!rr2 && rr1 == lr){
      tty_dbg("a_del1: " cr);
      a_del1[cr];
      return;
    }
    
    if(rr1 == lr && rr2 != lr){
      tty_dbg("a_ff1: " cr);
      a_ff1[cr];
      return;
    }
    if(rr2 == lr && rr1 != lr){
      tty_dbg("a_ff2: " cr);
      a_ff2[cr];
      return;
    }
  }
  
  a_solv[cr];
}
function actions_to_operations(    ref, sha1, sha2){
    
  for(ref in a_ff1){
    op_push_ff1[ref];
    op_fetch1[ref];
    op_fetch2[ref];
  }
  for(ref in a_ff2){
    op_push_ff2[ref];
    op_fetch1[ref];
    op_fetch2[ref];
  }
  if(deletion_allowed){
    for(ref in a_del1){
      op_push1[ref];
      op_del_local[ref];
    }
    for(ref in a_del2){
      op_push2[ref];
      op_del_local[ref];
    }
  }
  for(ref in a_restore){
    if(refs[ref][local_1]["sha"]){
      op_push1[ref];
      op_fetch1[ref];
    }
    if(refs[ref][local_2]["sha"]){
      op_push2[ref];
      op_fetch2[ref];
    }
  }
  for(ref in a_f1){
    op_fetch1[ref];
  }
  for(ref in a_f2){
    op_fetch2[ref];
  }
  for(ref in a_solv){
    if(!index(refs[ref][local_1]["ref"], local_1)){
      op_solv_push1[ref];
    }
    if(!index(refs[ref][local_2]["ref"], local_2)){
      op_solv_push2[ref];
    }
    op_solv_fetch1[ref];
    op_solv_fetch2[ref];
  }
}
function output_operations(){
  print "{[Result lines: push 1; push 2; fetch 1; fetch 2; del; push solv 1; push solv 2; fetch solv 1; fetch solv 2;]}"
  
  {
    for(ref in op_push_ff1){
      out_push1 = out_push1 "  '" refs[ref][local_1]["ref"] "':'" refs[ref][remote_1]["ref"] "'";
    }
    for(ref in op_push_ff2){
      out_push2 = out_push2 "  '" refs[ref][local_2]["ref"] "':'" refs[ref][remote_2]["ref"] "'";
    }
    
    for(ref in op_push1){
      out_push1 = out_push1 "  +'" refs[ref][local_1]["ref"] "':'" refs[ref][remote_1]["ref"] "'";
    }
    for(ref in op_push2){
      out_push2 = out_push2 "  +'" refs[ref][local_2]["ref"] "':'" refs[ref][remote_2]["ref"] "'";
    }
  }
  print out_push1;
  print out_push2;
  
  for(ref in op_fetch1){
    out_fetch1 = out_fetch1 "  +'" refs[ref][remote_1]["ref"] "':'" refs[ref][local_1]["ref"];
  }
  print out_fetch1;
  for(ref in op_fetch2){
    out_fetch2 = out_fetch2 "  +'" refs[ref][remote_2]["ref"] "':'" refs[ref][local_2]["ref"];
  }
  print out_fetch2;
  
  
  for(ref in op_del_local){
    if(refs[ref][local_1]["sha"]){
      out_del = out_del "  '" origin_1 "/" ref "'";
    }
    if(refs[ref][local_2]["sha"]){
      out_del = out_del "  '" origin_2 "/" ref "'";
    }
  }
  print out_del;
  
  {
    for(ref in op_solv_push1){
      out_push_solv1 = out_push_solv1 "  +'" refs[ref][local_1]["ref"] "':'" refs[ref][remote_1]["ref"] "'";
    }
    print out_push_solv1;
    for(ref in op_solv_push2){
      out_push_solv2 = out_push_solv2 "  +'" refs[ref][local_2]["ref"] "':'" refs[ref][remote_2]["ref"] "'";
    }
    print out_push_solv2;
    
    for(ref in op_solv_fetch1){
      out_fetch_solv1 = out_fetch_solv1 "  +'" refs[ref][remote_1]["ref"] "':'" refs[ref][local_1]["ref"] "'";
    }
    print out_fetch_solv1;
    for(ref in op_solv_fetch2){
      out_fetch_solv2 = out_fetch_solv2 "  +'" refs[ref][remote_2]["ref"] "':'" refs[ref][local_2]["ref"] "'";
    }
    print out_fetch_solv2;
  }
  
  print "{[End results]}";
}

function unlock_deletion(rr1, rr2, lr1, lr2){
  if(!rr1)
    return;
  if(!lr1)
    return;
  if(rr1 != rr2)
    return;
  if(lr1 != lr2)
    return;
  if(rr1 != lr2)
    return;
  
  deletion_allowed = 1;
}

function file_states() {
  switch (++file_num) {
    case 1:
      dest = remote_1;
      break;
    case 2:
      dest = remote_2;
      break;
    case 3:
      dest = local_1;
      origin = remote_1;
      break;
    case 4:
      dest = local_2;
      origin = remote_2;
      break;
  }
}
function common_key() {
  # Generates a common key for all 4 locations of every ref.
  $3 = $2
  split($3, split_refs, local_refs_prefix origin "/");
  if(split_refs[2]){
    # Removes "refs/remotes/current_origin/"
    $3 = split_refs[2];
  }else{
    # Removes "refs/heads/"
    sub("refs/[^/]*/", "", $3);
  }
}
function generate_missing_refs(){
  for(ref in refs){
    tty_dbg("zzzz");
    tty_dbg(ref);
    for(x in refs[ref]){
      tty_dbg(x " : " refs[ref][x]["ref"]);
    }

    if(!refs[ref][remote_1]["ref"])
      refs[ref][remote_1]["ref"] = remote_refs_prefix ref
    if(!refs[ref][remote_2]["ref"])
      refs[ref][remote_2]["ref"] = remote_refs_prefix ref
    if(!refs[ref][local_1]["ref"])
      refs[ref][local_1]["ref"] = local_refs_prefix origin_1 "/" ref
    if(!refs[ref][local_2]["ref"])
      refs[ref][local_2]["ref"] = local_refs_prefix origin_2 "/" ref
    
    tty_dbg();
    for(x in refs[ref]){
      tty_dbg(x " : " refs[ref][x]["ref"]);
    }
  }
}

function tty(msg){
  print msg >> tty_attached;
}
function tty_header(msg){
  tty("\n" msg "\n");
}
function tty_dbg(msg){
  if(!debug_on)
    return;

  #print "Œ " msg >> tty_attached;
  print "Œ " msg " Ð" >> tty_attached;
}

END{
  close(tty_attached);
}
