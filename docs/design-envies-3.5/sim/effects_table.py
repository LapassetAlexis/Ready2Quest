E = [("spot",.05,.25),("capture_humanoid",.10,.40),("shiny_undead",.15,.60),("aid_keep",.08,.30),("shiny_chain",.50,1.50),
("capture_named",.12,.45),("aid_zone",.25,1.00),("aid_refund",.20,.75),("capture_all (mascot)",.02,.10),
("decay_hunger",.10,.40),("treat_zone",.15,.60),("decay_energy",.10,.40),("decay_curiosity",.10,.40),("decay_mood",.10,.40),
("pet_mood",.25,1.00),("decay_all",.05,.25),("rest_energy",.15,.60),("mascot_decay",.04,.20),
("winter_treat",.10,.50),("winter_sack",.50,1.00),("winter_energy",.08,.40),("winter_nose",.03,.15),("winter_pet",.25,1.00),("winter_cold",.06,.30)]
v=lambda b,c,s,f: min(c,b*s*f)
for n,b,c in E:
    row=[]
    for s in (1,2,3.5,5):
        row.append(f"s{s}: {v(b,c,s,1):.2f}/{v(b,c,s,.75):.2f}/{v(b,c,s,.5):.2f}")
    print(f"| {n} | {b} | {c} | "+" | ".join(row)+" |")
