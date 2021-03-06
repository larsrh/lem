type nat = int

let nat_monus x y =
  let d = x - y in
    if d < 0 then
      0
    else
      d

let nat_pred x = nat_monus x 1

let int_mod i n =
  let r = i mod n in
  if (r < 0) then r + n else r

let int_div i n =
  let r = i / n in
  if (i mod n < 0) then r - 1 else r

let int32_mod i n =
  let r = Int32.rem i n in
  if (r < Int32.zero) then Int32.add r n else r

let int32_div i n =
  let r = Int32.div i n in
  if (Int32.rem i n < Int32.zero) then Int32.pred r else r

let int64_mod i n =
  let r = Int64.rem i n in
  if (r < Int64.zero) then Int64.add r n else r

let int64_div i n =
  let r = Int64.div i n in
  if (Int64.rem i n < Int64.zero) then Int64.pred r else r
