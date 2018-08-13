printh("----------------------")

eps = 0.000001

function lerp(a1,a2,r)
 return a1 * (1 - r) + a2 * r
end

-- take verts from
-- [-1,1] to [0,128]
function ndc_to_screen(poly)
 -- p8 display: 128*128
 local res = {}
 for p in all(poly) do
  local q = {}
  q[1] =  flr(63.5*(p[1]+1))
  q[2] =  flr(63.5*(1 - p[2]))
  add(res, q)
 end
 return res
end

-- take unformated list of verts
-- return singly-linked list of
-- edges with min/max and dxdy
-- sorted by xmin, bucketed by
-- ymin
-- (edges[ymin] = sorted list)
function edges_from_poly(poly)
 edges = {} -- bucket-sorted by ymin
 for i=1,#poly do
  local v1 = poly[i]
  local v2 = poly[i%#poly+1]
  
  -- if dydx = 0, skip
  if v1[2] ~= v2[2] then
   local xmin, ymin, ymax, dxdy
   dxdy = (v2[1] - v1[1]) / (v2[2] - v1[2])
   if v1[1] < v2[1] then
    xmin = v1[1]; xmax = v2[1]
   else
    xmin = v2[1]; xmax = v1[1]
   end
   if v1[2] < v2[2] then
    ymin = v1[2]; ymax = v2[2]
   else
    ymin = v2[2]; ymax = v1[2]
   end
   edge_data = {
    xmin=xmin,
    xmax=xmax,
    ymax=ymax,
    im=dxdy
   }
   if not edges[ymin] then
     -- no other edges in bin
    edges[ymin] = edge_data
   else
     -- need to sort by xmin
    local head = edges[ymin]
    if xmin < head.xmin then
     -- we are new head
     edge_data.next = head
     edges[ymin] = edge_data
    else
     local prev
     while head.next do
      prev = head
      head = head.next
      if xmin < head.xmin then
       -- insert between prev and head
       prev.next = edge_data
       edge_data.next = head
       break
      end
     end
     if not edge_data.next then
      -- we are leaf
      head.next = edge_data
     end
    end
   end
  end
 end
 return edges
end

-- draw the edges output by
-- edges_from_poly
function draw_edges(edges)
 for ymin,edge in pairs(edges) do
  repeat
   local x0, x1 = edge.xmin, edge.xmax
   if edge.im < 0 then
    x0, x1 = x1, x0
   end
   line(x0,ymin,x1,edge.ymax,8); color(6)
   edge=edge.next
  until(not edge)
 end
end

-- draw scanline at y from
-- active edge table
function draw_scanline(y, aet)
 local e1, e2 = aet, aet.next
 while e1 do
  rectfill(e1.x,y,e2.x,y)
  e1.x += e1.im
  e2.x += e2.im
  
  e1 = e2.next
  if (e1) then
   e2 = e1.next
  end
 end
end

-- copy active edge info from edge
function edge_to_aet(edge)
 local x = edge.xmin
 if edge.im < 0 then
  x = edge.xmax
 end
 return {
  ymax = edge.ymax,
  x    = x,
  im   = edge.im
 }
end

function all_to_aet(new_edge)
 aet = edge_to_aet(new_edge)
 local edge = aet
 while (new_edge.next) do
  new_edge = new_edge.next
  edge.next = edge_to_aet(new_edge)
  edge = edge.next
 end
 return aet
end

function scan(poly)

 local edges = edges_from_poly(poly)
 local aet = nil -- active edge table
 
 -- find min and max y
 local ymin, ymax = 128, -1
 for p in all(poly) do
  ymin = min(ymin,p[2])
  ymax = max(ymax,p[2])
 end

 -- render scanlines
 for y=ymin,ymax-1 do
  -- remove finished edges
  local last, edge = nil, aet
  while edge do
   if edge.ymax == y then
    -- remove this edge
    if last then
     last.next = edge.next
    else
     aet = edge.next
    end
   else
    last = edge
   end
   edge = edge.next
  end
  -- add new edges
  if edges[y] then
   local new_edge = edges[y]
   
   if not aet then
    aet = all_to_aet(new_edge)
   else
    local last, edge = nil, aet
    while edge and new_edge do
     -- add in front of further edge
     if new_edge.xmin < edge.x then
      new_entry = edge_to_aet(new_edge)
      if last then
       last.next = new_entry
      else
       aet = new_entry
      end
      new_entry.next = edge
      last = new_entry
      new_edge = new_edge.next
     else
      last = edge
      edge = edge.next
     end
    end
    if not edge then
     last.next = all_to_aet(new_edge)
    end
   end
  end
  
  draw_scanline(y, aet)
 end
 --draw_edges(edges)
end


--[[
 matrices and vectors
--]]

--vector functions

-- vector constructor
function v4(x,y,z,w)
 return {x or 0,y or 0,z or 0,w or 1}
end

-- string conversion
function v2s(v)
 return ""..v[1]..","..v[2]
end
function v3s(v)
 return v2s(v)..","..v[3]
end
function v4s(v)
 return v3s(v)..","..v[4]
end

-- mag
function mag2(v) return sqrt(dot2(v,v)) end
function mag3(v) return sqrt(dot3(v,v)) end
-- dot product
function dot2(v1,v2) return v1[1]*v2[1] + v1[2]*v2[2] end
function dot3(v1,v2) return dot2(v1,v2) + v1[3]*v2[3] end
--function dot4(v1,v2) return dot3(v1,v2) + v1[4]*v2[4] end
-- cross product
function cross2(v1,v2) return -v1[2]*v2[1] + v1[1]*v2[2] end
function cross3(v1,v2) return {v1[2]*v2[3]-v1[3]*v2[2],v1[3]*v2[1]-v1[1]*v2[3],v1[1]*v2[2]-v1[2]*v2[1]} end

-- addition
function add4(v1,v2) return {v1[1]+v2[1],v1[2]+v2[2],v1[3]+v2[3],v1[4]+v2[4]} end
-- subtraction
function sub4(v1,v2) return {v1[1]-v2[1],v1[2]-v2[2],v1[3]-v2[3],v1[4]-v2[4]} end

--[[
 matrix functions
]]--

function mulmat4mat4(l,r)
 return mat4({
  l[1]*r[1]+l[2]*r[5]+l[3]*r[9]+l[4]*r[13],
  l[1]*r[2]+l[2]*r[6]+l[3]*r[10]+l[4]*r[14],
  l[1]*r[3]+l[2]*r[7]+l[3]*r[11]+l[4]*r[15],
  l[1]*r[4]+l[2]*r[8]+l[3]*r[12]+l[4]*r[16],
  l[5]*r[1]+l[6]*r[5]+l[7]*r[9]+l[8]*r[13],
  l[5]*r[2]+l[6]*r[6]+l[7]*r[10]+l[8]*r[14],
  l[5]*r[3]+l[6]*r[7]+l[7]*r[11]+l[8]*r[15],
  l[5]*r[4]+l[6]*r[8]+l[7]*r[12]+l[8]*r[16],
  l[9]*r[1]+l[10]*r[5]+l[11]*r[9]+l[12]*r[13],
  l[9]*r[2]+l[10]*r[6]+l[11]*r[10]+l[12]*r[14],
  l[9]*r[3]+l[10]*r[7]+l[11]*r[11]+l[12]*r[15],
  l[9]*r[4]+l[10]*r[8]+l[11]*r[12]+l[12]*r[16],
  l[13]*r[1]+l[14]*r[5]+l[15]*r[9]+l[16]*r[13],
  l[13]*r[2]+l[14]*r[6]+l[15]*r[10]+l[16]*r[14],
  l[13]*r[3]+l[14]*r[7]+l[15]*r[11]+l[16]*r[15],
  l[13]*r[4]+l[14]*r[8]+l[15]*r[12]+l[16]*r[16]
 })
end

function mulmat4vec4(l,r)
 if #r==4 then return { l[1]*r[1]+l[2]*r[2]+l[3]*r[3]+l[4]*r[4], l[5]*r[1]+l[6]*r[2]+l[7]*r[3]+l[8]*r[4], l[9]*r[1]+l[10]*r[2]+l[11]*r[3]+l[12]*r[4], l[13]*r[1]+l[14]*r[2]+l[15]*r[3]+l[16]*r[4] }
 else return { l[1]*r[1]+l[5]*r[2]+l[9]*r[3]+l[13]*r[4], l[2]*r[1]+l[6]*r[2]+l[10]*r[3]+l[14]*r[4], l[3]*r[1]+l[7]*r[2]+l[11]*r[3]+l[15]*r[4], l[4]*r[1]+l[8]*r[2]+l[12]*r[3]+l[16]*r[4] }
 end
end

function mulmat4scalar(l,r)
 if type(r) == "number" then r, l = l, r end
 return mat4({r[1]*l,r[2]*l,r[3]*l,r[4]*l,r[5]*l,r[6]*l,r[7]*l,r[8]*l,r[9]*l,r[10]*l,r[11]*l,r[12]*l,r[13]*l,r[14]*l,r[15]*l,r[16]*l})
end

function addmat4scalar(l,r)
 if type(r) == "number" then r, l = l, r end
 return mat4({r[1]+l,r[2]+l,r[3]+l,r[4]+l,r[5]+l,r[6]+l,r[7]+l,r[8]+l,r[9]+l,r[10]+l,r[11]+l,r[12]+l,r[13]+l,r[14]+l,r[15]+l,r[16]+l})
end

function submat4scalar(l,r)
 if type(r) == "number" then r, l = l, r end
 return addmat4scalar(l,-r)
end

-- matrix constructor
-- overloads +,- and * for
-- matrices and scalars
function mat4(t)
 local t = t or 1
 if type(t) == "number" then t = {t,t,t,t} end
 if #t == 4 then
  t = {t[1],0,0,0,0,t[2],0,0,0,0,t[3],0,0,0,0,t[4]}
 end
 setmetatable(t,{
  __add=function(l,r)
   if type(l) == "number" or type(r) == "number" then
    return addmat4scalar(l,r)
   else return mat4({l[1]+r[1],l[2]+r[2],l[3]+r[3],l[4]+r[4],l[5]+r[5],l[6]+r[6],l[7]+r[7],l[8]+r[8],l[9]+r[9],l[10]+r[10],l[11]+r[11],l[12]+r[12],l[13]+r[13],l[14]+r[14],l[15]+r[15],l[16]+r[16]}) end end,
  __sub=function(l,r)
   if type(l) == "number" or type(r) == "number" then
    return submat4scalar(l,r)
   else return mat4({l[1]-r[1],l[2]-r[2],l[3]-r[3],l[4]-r[4],l[5]-r[5],l[6]-r[6],l[7]-r[7],l[8]-r[8],l[9]-r[9],l[10]-r[10],l[11]-r[11],l[12]-r[12],l[13]-r[13],l[14]-r[14],l[15]-r[15],l[16]-r[16]}) end end,
  __mul=function(l,r)
   if type(l) == "number" or type(r) == "number" then
    return mulmat4scalar(l,r)
   elseif #l == 4 or #r == 4 then
    return mulmat4vec4(l,r)
   elseif #l == 16 and #r == 16 then
    return mulmat4mat4(l,r)
   else
    printh("error: invalid operands to matrix multiplication")
    return {}
   end
  end
  })
 return t
end

function det3(v1,v2,v3)
 return v1[1]*(v2[2]*v3[3]-v2[3]*v3[2])+
        v2[1]*(v3[2]*v1[3]-v3[3]*v1[2])+
        v3[1]*(v1[2]*v2[3]-v1[3]*v2[2])
end

function printh_matrix(m)
 for i=0,3 do
  str = ""
  for j=1,4 do
   str = str..m[j+4*i]..", "
  end
  printh(str)
 end
end


--[[
new scanline stuff
--]]

function scan_flat_tri(a,b,c)
 local dy=sgn(a[2]-c[2])
 local dx1dy = dy*(a[1]-c[1])/(a[2]-c[2])
 local dx2dy = dy*(b[1]-c[1])/(a[2]-c[2])

 local x1,x2=c[1],c[1]
 --printh("scanning from "..c[2].." to "..a[2].." in "..dy)
 --printh("a: "..v2s(a))
 --printh("b: "..v2s(b))
 --printh("c: "..v2s(c))
 --printh("dx1dy: "..dx1dy)
 --printh("dx2dy: "..dx2dy)
 for y=c[2],a[2],dy do
  rectfill(x1,y,x2,y)
  x1+=dx1dy
  x2+=dx2dy   
 end
end

function scan_tri(a,b,c)
 --printh(".."..c[1]..", "..c[2])
 if a[1]==b[1]==c[1] or a[2]==b[2]==c[2] then
  -- skip
  printh("degenerate tri")
 else
  -- sort triangles so a.y>=b.y>c.y
  if a[2]< b[2] then a,b=b,a end
  if a[2]< c[2] then a,c=c,a end
  if b[2]< c[2] then b,c=c,b end
  if b[2]==c[2] then a,c=c,a end
 
  if a[2]==b[2] then
   scan_flat_tri(a,b,c)
  else
   local d = {a[1] + (b[2]-a[2]) * (c[1]-a[1])/(c[2]-a[2]),
              b[2]}
   scan_flat_tri(b,d,a)
   scan_flat_tri(b,d,c)
  end
 end
end

function tri_strip_to_tris(strip)
 local tris = {}
 for i=1,#strip-2 do
  -- need to swap even tris
  -- to maintain ccw orientation
  local m = i % 2
  tris[i] = {strip[i+1-m],strip[i+m],strip[i+2]}
 end
 return tris
end

function backface_cull(tris)
 local res,n={},1
 for i=1,#tris do
  local det = det3(tris[i][1],tris[i][2],tris[i][3])
  if det >= 0 then
   res[n] = tris[i]
   n += 1
  end
 end
 return res
end


function outline_strip(strip)
 local tris=tri_strip_to_tris(strip)
 for t in all(tris) do
  local det = det3(t[1],t[2],t[3])
  local ccw = det >= 0
  local s = ndc_to_screen(t)
  color(11)
  if not ccw then color(8) end
  line(s[1][1],s[1][2],s[2][1],s[2][2])
  line(s[1][1],s[1][2],s[3][1],s[3][2])
  line(s[2][1],s[2][2],s[3][1],s[3][2])
 end
end

--[[
 transformation matrices
--]]

function persp(w,h,n,f)
 local t = 1/(n-f)
 return mat4({2*n/w,0, 0,0,
             0,2*n/h,  0,0,
             0,0,(f+n)*t,2*f*n*t,
             0,0, -1,    0})
end

function trans(x,y,z)
 local t = mat4()
 t[4],t[8],t[12]=x,y,z
 return t
end

function scale(x,y,z)
 local s = mat4()
 s[1] = x; s[6] = y; s[11] = z
 return s
end

function rotx(a)
 local rx = mat4()
 rx[6]  =  cos(a) -- y
 rx[7]  = -sin(a) -- yz
 rx[10] =  sin(a) -- zy
 rx[11] =  cos(a) -- z
 return rx
end

function roty(a)
 local ry = mat4()
 ry[1]  =  cos(a) -- x
 ry[3]  =  sin(a) -- xz
 ry[9]  = -sin(a) -- zx
 ry[11] =  cos(a) -- z
 return ry
end

function rotz(a)
 local rz = mat4()
 rz[1] =  cos(a) -- x
 rz[2] = -sin(a) -- xy
 rz[5] =  sin(a) -- yx
 rz[6] =  cos(a) -- y
 return rz
end



--[[
 rendering
--]]

function apply_transform(poly, t)
 local res = {}
 for v in all(poly) do
  add(res,t*v)
 end
 return res
end

function proj_to_ndc(poly)
 local res = {}
 for v in all(poly) do
  add(res,{v[1]/v[4],v[2]/v[4],v[3]/v[4]})
 end
 return res
end

clip_planes = {
 { 0, 0, 1},
 { 0, 0,-1},
 { 1, 0, 0},
 { 0, 1, 0},
 {-1, 0, 0},
 { 0,-1, 0}
}

function clip_tri(poly)
 local poly_next = {}

 printh("  input poly")
 for v in all(poly) do
  printh("    "..v4s(v))
 end
 -- hacky pre-w clipping
 for i=1,#poly do
  local v = poly[i]
  if v[4] >= 0 then
   add(poly_next,v)
  else
   local v_prev = poly[((i-2)%#poly)+1]
   local v_next = poly[((i)%#poly)+1]
   for u in all({v_prev,v_next}) do
    if u[4] >= 0 then
     ratio = (0.1 - v[4]) / (u[4] - v[4])
     local dx = u[1] - v[1]
     local dy = u[2] - v[2]
     local dz = u[3] - v[3]
     local dw = u[4] - v[4]
     if 0 <= ratio and ratio <= 1 then
      add(poly_next,v4(v[1] + ratio*dx, v[2] + ratio*dy, v[3] + ratio*dz, v[4] + ratio*dw))
     end
    end
   end
  end
 end

 poly = poly_next
 poly_next = {}

 printh("  output poly")
 for v in all(poly) do
  printh("    "..v4s(v))
 end

 for plane in all(clip_planes) do
  for i=1,#poly do
   local v = poly[i]
   local w_v = v[4]

   local p_v = {plane[1]*w_v,plane[2]*w_v,plane[3]*w_v}
            
   if dot3(p_v,v) <= dot3(p_v,p_v) then
    -- v is inside current plane and should not be clipped
    add(poly_next,v)
   else
    -- edges of v should be clipped 
    local v_prev = poly[((i-2)%#poly)+1]
    local v_next = poly[((i)%#poly)+1]
    for u in all({v_prev, v_next}) do
     local w_u = u[4]
     local p_u = {plane[1]*w_u,plane[2]*w_u,plane[3]*w_u}

     if dot3(p_u,u) <= dot3(p_u,p_u) then
      -- todo - could just do w division here

      local dx = u[1] - v[1]
      local dy = u[2] - v[2]
      local dz = u[3] - v[3]
      local dw = u[4] - v[4]

      local a = dot3(plane, v)
      local b = dot3(plane, u)

      local ratio = (a - v[4]) / (u[4] - v[4] - b + a)
                
      if 0 <= ratio and ratio <= 1 then
       add(poly_next,v4(v[1] + ratio*dx, v[2] + ratio*dy, v[3] + ratio*dz, v[4] + ratio*dw))
      end -- if
     end -- if
    end -- for
   end -- else
  end -- for
  poly = poly_next
  poly_next = {}
 end -- for
 
 return poly
end

function render(poly, viewprojection)
 poly = apply_transform(poly, viewprojection)
 poly = proj_to_ndc(poly)
 poly = ndc_to_screen(poly)
-- poly = clip_rect(poly)
 scan(poly)
end

function w_divide(verts)
 local res = {}
 for i=1,#verts do
  local w = verts[i][4]
  res[i] = {verts[i][1]/w,verts[i][2]/w,verts[i][3]/w}
 end
 return res
end

function render_strip(strip, viewproject, col, cull)
 if cull == nil then cull = true end
 printh("received strip verts")
 printh(" applying transform")
 strip = apply_transform(strip, viewproject)
 for v in all(strip) do
  printh("  "..v4s(v))
 end

 --strip = proj_to_ndc(strip)
 
 local tris = tri_strip_to_tris(strip)
 if cull then
  tris = backface_cull(tris)
  printh(" "..#tris.." tris after culling")
 end
 
 for i=1,#tris do
  local clip_res = clip_tri(tris[i])
  local w_div = w_divide(clip_res)
  local ndc = ndc_to_screen(w_div)
  printh(" clip size: "..#clip_res)
  printh(" clip results:")
  for i=1,#clip_res do
   printh("  "..v4s(clip_res[i]))
  end
  printh(" wdiv results:")
  for i=1,#clip_res do
   printh("  "..v3s(w_div[i]))
  end
  --[[
  printh(" ndc results:")
  for i=1,#clip_res do
   printh("  "..v2s(ndc[i]))
  end
  --]]
  for j=1,#ndc-2 do
   --local tri = {ndc[1],ndc[j+1],ndc[j+2]}
   --printh(v3s(tri))
   
   color(col)
   scan_tri(ndc[1],ndc[j+1],ndc[j+2])
   color(1)
   line(ndc[1][1],ndc[1][2],ndc[j+1][1],ndc[j+1][2])
   line(ndc[1][1],ndc[1][2],ndc[j+2][1],ndc[j+2][2])
   line(ndc[j+1][1],ndc[j+1][2],ndc[j+2][1],ndc[j+2][2])
  end
  for j=1,#ndc do
   circfill(ndc[j][1], ndc[j][2],3,j)
  end
 end
end

left_wall = {
 v4(-1, 1,-1),
 v4(-1, 1,-10),
 v4(-1,-1,-10),
 v4(-1,-1,-1)
}

right_wall = {
 v4( 1, 1,-1),
 v4( 1, 1,-10),
 v4( 1,-1,-10),
 v4( 1,-1,-1)
}

left_wall_strip = {
 v4(-1,-1,-1.05),
 v4(-1,-1,-10.05),
 v4(-1, 1,-1.05),
 v4(-1, 1,-10.05)
}
right_wall_strip = {
 v4( 1, 1,-1),
 v4( 1, 1,-10),
 v4( 1,-1,-1),
 v4( 1,-1,-10)
}

test_s = {
 v4( 1, 1,-1),
 v4( 1,-1,-1),
 v4( 1,-1,-12),
}

proj = persp(1,1,1,10)
ry, rx = 0, 0
--poke(0x5f2d,1) -- initiate mouse

projview = proj

px = 0
pz = 0

last_mx = 0
last_my = 0

reproject = false

function display_debug_info()
 print("cpu: "..100*stat(1).." %", 4,4,7)
 print("mem: "..stat(0).." kb",4,12,7)
 print("mx: "..last_mx, 100, 4, 7)
 print("my: "..last_my, 100, 12,7)
 circfill(last_mx,last_my,1,9)
end

function _draw()
 if reproject then
  projview = proj*roty(ry)*rotx(rx)*trans(px,0,pz)
 end
 
 cls()
 color(5)
 --[[
 render(left_wall, projview) --view)
 render(right_wall, projview)--view)
 --]]
 
 local col = 6
 --[
 render_strip(left_wall_strip, projview,col,false) --view)
 render_strip(right_wall_strip, projview,col,false)--view)
 --]]
 printh("pos: "..px..", "..pz)
 render_strip(test_s, projview,9,false)
 color(9)
 
 display_debug_info()
end

function _update()
 if btn(0,1) then test_s[1][1] -= 0.1 end
 if btn(1,1) then test_s[1][1] += 0.1 end
 if btn(2,1) then test_s[1][3] += 0.1 end
 if btn(3,1) then test_s[1][3] -= 0.1 end
 if btn(1) then px -= 0.1 end
 if btn(0) then px += 0.1 end
 if btn(2) then pz += 0.1 end
 if btn(3) then pz -= 0.1 end
 if btn(1) or btn(0) or btn(2) or btn(3) then 
  reproject = true
 end
 
 local mx,my = stat(32), stat(33)
 
 if mx ~= last_mx or my ~= last_my then
  local dx,dy
  dx = last_mx - mx
  dy = last_my - my
  rx -= dy/100
  ry -= dx/100
  print(rx)
  reproject=true
 end
 last_mx = mx
 last_my = my
end
