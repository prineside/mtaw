-- DFF export // by DENISka

rollout Export_prog "Progress Test"
(
progressbar prog
progressbar prog_all
)
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

fn getFID n maxn = ((mod (n-1) maxn) as integer + 1)

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

fn writeStringZero f str N = (
local i, len

writeString f str
len = str.count
if len<N do 
 for i = 1 to (N-len-1) do writeByte f 0x0 #unsigned
N - len 
)

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

fn writeStringNoZero f str = (
local i

for i = 1 to str.count do writebyte f (bit.charAsInt str[i]) #unsigned
)

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------


fn Bsphere o = (
local c = in coordsys local o.center
local r = -1, v, res = #(), i

for i = 1 to o.mesh.numverts do (
 v = length (c - (getvert o.mesh i))
 if v>r then r = v
 )

res[1] = c; res[2] = r
res
)

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

fn getTexture mat = (
local res = #()

if isKindof mat Standard then (
 if mat.diffuseMap!=undefined do res[1] = getFileNameFile mat.diffuseMap.fileName
 if mat.opacityMap!=undefined do res[2] = getFileNameFile mat.opacityMap.fileName
)
else
 if isKindOf mat Gta_Mtl do (
  if mat.ColorMap!=undefined do res[1] = getFileNameFile mat.ColorMap.fileName
  if mat.AlphaMap!=undefined do res[2] = getFileNameFile mat.AlphaMap.fileName
 )
res
) -- fn getTextura

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

fn getChils s n = (
local res = #(#(),#()), i, subobj = s.children, b

if subobj.count>0 do
for i = 1 to subobj.count do (
 append res[1] subobj[i]
 append res[2] n
 if subobj[i].children.count > 0 do (
  b = getChils subobj[i] (i+n)
  join res[1] b[1]
  join res[2] b[2]
 )
)

res
) -- end getSub

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

fn writeHeader f ID Size = (
writelong f ID
writelong f Size
writelong f 0x1803FFFF
)

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

fn writeGeometry f obja haveVC haveNVC NVCpar haveNormals geomLight extype = (
local obj = copy obja
local VC = #(), NVC = #(), MV = #(), VX = #(), FS = #(), FID = #(), Mats = #(), vychet = #(), tex = #()
local MFace = #(), freeMap = #(), NumMV = #(), sig = #(1, 2, 3), Pos = #(), Bsph = #(), TStr = #()
local i, j, k, Flags = 6, ff, MatCount = 1, ObjMat = Obj.material, size, MatCount2 = 0
local objMesh, NumF, NumV
local VCsup = NVCsup = true

obj.position = [0,0,0]
obj.rotation = (quat 0 0 0 1)
resetXForm obj
convertToMesh obj

objMesh = obj --.mesh
NumF = ObjMesh.NumFaces

if haveNormals then Flags += 16
if haveVC then Flags += 8
if geomLight then Flags += 32

--Export_prog.prog.value = 60

if haveNVC then
 if meshOp.getMapSupport ObjMesh -1 then NumMV[1] = meshop.getNumMapVerts ObjMesh -1
                                    else (NumMV[1] = 0; NVCsup = false)
		   else (NumMV[1] = -1; NVCsup = false)
if haveVC then 
 if meshOp.getMapSupport ObjMesh 0 then NumMV[2] = meshop.getNumMapVerts ObjMesh 0
                                   else (NumMV[2] = 0; VCsup = false)
		  else (NumMV[2] = -1; VCsup = false)
NumMV[3] = meshop.getNumMapVerts ObjMesh 1


if extype == 2 then sig = #(3,2,1)
else
for i = 1 to 3 do
 for j = 1 to 3 do
  if NumMV[sig[i]]>NumMV[sig[j]] do swap sig[i] sig[j]

NumV = NumMV[sig[1]]

if isKindOf ObjMat MultiMaterial then MatCount = getNumSubMtls ObjMat

for i = 1 to NumF do (
 Export_prog.prog.value = i*90/NumF --80/(NumF-i+1) + 20
 if haveNVC and NVCsup then MFace[1] = meshOp.getMapFace ObjMesh -1 i
 if haveVC and VCsup then MFace[2] = meshOp.getMapFace ObjMesh 0 i
 MFace[3] = meshOp.getMapFace ObjMesh 1 i
 ff = getFace ObjMesh i
 FS[i] = MFace[sig[1]]
 FID[i] = getFID (getFaceMatID ObjMesh i) MatCount
 if Mats[FID[i]]==undefined do ( 
   Mats[FID[i]] = (if isKindOf ObjMat MultiMaterial then ObjMat[FID[i]] else ObjMat)
   Tstr[FID[i]] = #()
   )
 append TStr[FID[i]] FS[i]
 
 for j = 1 to 3 do
  if freeMap[MFace[sig[1]][j]]==undefined do 
  (
   if haveVC do
    if VCsup then
      VC[MFace[sig[1]][j]] = (meshOp.getMapVert ObjMesh 0 MFace[2][j]) * 255
	 else VC[MFace[sig[1]][j]] = [255, 255, 255]
   if haveNVC do
    if NVCsup then
     NVC[MFace[sig[1]][j]] = (meshOp.getMapVert ObjMesh -1 MFace[1][j]) * 255
     else NVC[MFace[sig[1]][j]] = [255, 255, 255]
	 
   MV[MFace[sig[1]][j]] = meshOp.getMapVert ObjMesh 1 MFace[3][j]
   VX[MFace[sig[1]][j]] = getVert ObjMesh ff[j]
   freeMap[MFace[sig[1]][j]] = 1
  ) -- j
) ----- for i


for i = 1 to MatCount do vychet[i] = 1

for i = 1 to MatCount do
  if Mats[i]!=undefined do (
    tex[i] = getTexture Mats[i]
	MatCount2 += 1
    for j = i to MatCount do vychet[j] += 1
  )
 
Export_prog.prog.value = 91
--break ()
--------
Pos[1] = ftell f
writeHeader f 0x0F 20000

---- Geom structure start
Size = 40 + NumF*8 + NumV*20; if haveVC do Size+= NumV*4
writeHeader f 0x01 Size

writeshort f flags #unsigned
writeshort f 1 #unsigned
writelong f NumF #unsigned
writelong f NumV #unsigned
writelong f 1 #unsigned

if haveVC do 
 for i= 1 to NumV do ( ------- V color
  if VC[i]!=undefined then
      for j = 1 to 3 do
          writebyte f VC[i][j] #unsigned
		              else (writebyte f 0; writebyte f 0; writebyte f 0)
  writebyte f 0xFF #unsigned
 )
 Export_prog.prog.value = 93
 
for i = 1 to NumV do 
if MV[i]!=undefined then ( -------- UV coords
 writefloat f MV[i].x
 writefloat f (-MV[i].y)
)
else (writefloat f 0; writefloat f 0)
Export_prog.prog.value = 95

for i = 1 to NumF do ( -------  faces
 writeshort f (FS[i][2]-1) #unsigned
 writeshort f (FS[i][1]-1) #unsigned
 writeshort f 0
 writeshort f (FS[i][3]-1) #unsigned
)
Export_prog.prog.value = 97

-- B SPHERE
Bsph = Bsphere obj
writefloat f Bsph[1][1]
writefloat f Bsph[1][2]
writefloat f Bsph[1][3]
writefloat f Bsph[2]

writelong f 1 #unsigned -- unk
writelong f 0  -- unk

Export_prog.prog.value = 98

for i = 1 to NumV do 
if VX[i]!=undefined then ( -------- verts
 writefloat f VX[i].x
 writefloat f VX[i].y
 writefloat f VX[i].z
)
else (writefloat f 0; writefloat f 0; writefloat f 0)

Export_prog.prog.value = 99
---- Geom structure end
--
--
--
---- Material list start
Pos[2] = ftell f
writeHeader f 0x08 10000

writeHeader f 0x01 (MatCount2*4 + 4) -- structure
writelong f MatCount2 #unsigned
for i = 1 to MatCount2 do writelong f -1

-- materials
for i = 1 to MatCount do
 if mats[i]!=undefined do (
  Pos[3] = 52
  if tex[i][1]!=undefined do (
   Pos[5] = tex[i][1].count + 4 - (mod tex[i][1].count 4)
   Pos[4] = 64 + Pos[5]
   if tex[i][2] != undefined then Pos[4] += (Pos[6] = tex[i][2].count + 4 - (mod tex[i][2].count 4))
                             else Pos[4] += (Pos[6] = 4)
   Pos[3] += Pos[4]
  )
  
  writeHeader f 0x07 Pos[3] -- material
  writeHeader f 0x01 28 -- structure
  
  writelong f 0 -- unk
  if isKindOf Mats[i] gta_mtl then (
   writebyte f Mats[i].color.r #unsigned
   writebyte f Mats[i].color.g #unsigned
   writebyte f Mats[i].color.b #unsigned
   writebyte f Mats[i].alpha #unsigned
   
   writelong f 16688092 #unsigned -- unk
   
   if tex[i][1]==undefined then writelong f 0 #unsigned
                           else writelong f 1 #unsigned
   writefloat f Mats[i].amb
   writefloat f Mats[i].spc
   writefloat f Mats[i].dif			   
  )
  else (
   writebyte f Mats[i].diffuse.r #unsigned
   writebyte f Mats[i].diffuse.g #unsigned
   writebyte f Mats[i].diffuse.b #unsigned
   writebyte f (Mats[i].opacity * 2.55) #unsigned
   
   writelong f 16688092 #unsigned -- unk
   
   if tex[i][1]==undefined then writelong f 0 #unsigned
                           else writelong f 1 #unsigned
   writefloat f (Mats[i].diffuseMapAmount/100)
   writefloat f (Mats[i].soften)					   
   writefloat f (Mats[i].ambientMapAmount/100)
  )
  --- end mat stucture
  
  if tex[i][1]!=undefined do (
   writeHeader f  0x06  (Pos[4]-12) -- texture
   writeHeader f  0x01  4 -- structure
   writeshort f 0x106 #unsigned
   writeshort f 1 #unsigned
   
   writeHeader f 0x02 Pos[5]
   writeStringZero f tex[i][1] Pos[5]
   writeHeader f 0x02 Pos[6]
   if tex[i][2]!= undefined then
     writeStringZero f tex[i][2] Pos[6]
	else writelong f 0
   
   writeHeader f 0x03 0 -- texture extension 
  ) -- if tex[1]....
  
  writeHeader f 0x03 0 -- material extension 
  
 ) -- end for i = 1 to MatCount
 
--
------------ end material list
--
--
--
--

Pos[3] = ftell f

Pos[4] = 28 + 12 + MatCount2*8 + NumF*12
if haveNVC do Pos[4]+= NumV*4 + 16

writeHeader f 0x03 Pos[4] -- geometry extension

writeHeader f 0x50E (12 + MatCount2*8 + NumF*12)  ---------  Bin Mesh PLG

writelong f 0 -- unk
writelong f MatCount2 #unsigned -- split count
writelong f (NumF*3) #unsigned -- index count

j= 0
for i = 1 to MatCount do
 if Tstr[i]!=undefined do (
  writelong f (Tstr[i].count*3) #unsigned
  writelong f  j  #unsigned
   for k = 1 to Tstr[i].count do (
    writelong f (Tstr[i][k][1]-1) #unsigned
	writelong f (Tstr[i][k][2]-1) #unsigned
	writelong f (Tstr[i][k][3]-1) #unsigned
   )
  j+=1
 ) -- end bin mesh i


writeHeader f 0x253F2FD 4
writelong f 0 

--- NVC
if haveNVC do (
 writeHeader f 0x253F2F9 (NumV*4 + 4)
 writebyte f NVCpar[1] #unsigned
 writebyte f NVCpar[2] #unsigned
 writebyte f NVCpar[3] #unsigned
 writebyte f NVCpar[4] #unsigned
 
 for i = 1 to NumV do (
  if NVC[i]!=undefined then 
     for j = 1 to 3 do
       writebyte f NVC[i][j] #unsigned
	 else (writebyte f 0; writebyte f 0; writebyte f 0)
  writebyte f 255 #unsigned
 )
)

Export_prog.prog.value = 100

---------------------- write sizes
pos[4] = ftell f -- end

fseek f (pos[1] + 4) #seek_set
writelong f (pos[4]-pos[1]-12) #unsigned

fseek f (pos[2]-pos[1]-4) #seek_cur
writelong f (pos[3]-pos[2]-12) #unsigned

fseek f pos[4] #seek_set

delete obj

--format "NumMV = %\nsig = %\nNUM VERTS = %\n" NumMV sig NumV
--format "VC = %\nNVC = %\nVX = %\nMTLS = %\nVYCHET = %\nID = %\n" vc nvc vx mats vychet FID
--format "TRISTRIP = %\nMatCount2 = %\n" TStr MatCount2
									 
) --------- fn write geometry

------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------

fn DFFexport f Eobj haveVC haveNVC NVCpar haveNormals geomLight extype = (
local i, j, k, ch, size
local Objs = #(Eobj), Ligs = #(), GObjs = #(), Prnt = #(-1), Pos = #()
local RootMatrix = Eobj.transform, Matr

if Eobj.parent != undefined then format "obj:% is part of something\n" Eobj.name
else (
--Export_prog.prog.value = 1
ch = getChils Eobj 0
join Objs ch[1]; --format "OBJS:%\n" Objs
join Prnt ch[2]; --format "PRNT:%\n" Prnt

for i = 1 to Objs.count do 
 if isKindOf Objs[i] GeometryClass then append GObjs i
 
for i = 1 to Objs.count do
 if isKindOf Objs[i] Light then append Ligs i

--format "GEOM:%\nLIGHTS:%\n" GObjs Ligs
--Export_prog.prog.value = 5

-- CLUMP
writeHeader f 0x10 50000
writeHeader f 0x01 12

writelong f GObjs.count #unsigned
writelong f 0
writelong f 0

size = 16 + Objs.count*56
for i = 1 to Objs.count do size += 24 + Objs[i].name.count

writeheader f 0x0E size --------------------------------- FRAME LIST
writeheader f 0x01 (Objs.count*56 + 4) -- structure
writelong f Objs.count #unsigned -- count

for i = 1 to Objs.count do (
 if i == 1 then
  Matr = in coordsys local Objs[i].rotation as matrix3
 else (
  Matr = in coordsys parent Objs[i].rotation as matrix3
  Matr.position = in coordsys parent Objs[i].position
 )
 for j = 1 to 4 do
  for k = 1 to 3 do 
   writefloat f Matr[j][k]
 writelong f Prnt[i] #unsigned -- parent
 if (Prnt[i]==-1) and (Objs.count>1) then writelong f 131075 #unsigned
                else writelong f 0 #unsigned
) --  i = 1 to Objs.count
--Export_prog.prog.value = 10

for i = 1 to Objs.count do (
 writeheader f 0x03 (12 + Objs[i].name.count)
 writeheader f 0x253F2FE (Objs[i].name.count)
 writeStringNoZero f Objs[i].name
)

------------ geometry list
--
--
pos[1] = ftell f
writeHeader f 0x1A 30000
writeheader f 0x01 4
writelong f GObjs.count #unsigned
--Export_prog.prog.value = 15

for i = 1 to GObjs.count do
 writeGeometry f Objs[GObjs[i]] haveVC haveNVC NVCpar haveNormals geomLight extype
 
pos[2] = ftell f
fseek f (pos[1]+4) #seek_set
writelong f (pos[2]-pos[1]-12) #unsigned
fseek f pos[2] #seek_set

------------- ATOMIC
--
--
for i = 1 to GObjs.count do (
 writeheader f 0x14 40 -- atom
 writeheader f 0x01 16 -- structure
 
 writelong f (GObjs[i]-1) #unsigned
 writelong f (i-1) #unsigned
 writelong f 5 #unsigned
 writelong f 0 #unsigned
 
 writeheader f 0x03 0
 
) -- atomic i

------------- LIGHTS
--
--
for i = 1 to Ligs.count do (
 writeheader f 0x01 4
 writelong f (Ligs[i]-1) #unsigned
 
 writeHeader f 0x12 48 -- light
 writeHeader f 0x01 24 -- structure
 
 writefloat f Objs[Ligs[i]].farAttenEnd
 writefloat f (Objs[Ligs[i]].rgb.r/255.0)
 writefloat f (Objs[Ligs[i]].rgb.g/255.0)
 writefloat f (Objs[Ligs[i]].rgb.b/255.0)
 
 writelong f 0
 writeshort f 3 #unsigned
 writeshort f 128 #unsigned
 
 writeheader f 0x03 0
)

----------- CLUMP EXTENSION
--
--
writeheader f 0x03 0
size = ftell f

fseek f 4 #seek_set
writelong f (size-12) #unsigned


) -- if not have parent

) ------------------------------------------------------ END FN DFF EXPORT


------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------
rollout dffexport_rol "export DFF" width:143 height:275
(
	button exp "EXPORT" pos:[11,5] width:115 height:41
	checkbox havenvc "night vertex colors" pos:[15,112] width:100 height:19 checked:true
	spinner nvcpar1 "param 1     " pos:[23,136] width:101 height:16 range:[0,255,0] type:#integer
	spinner nvcpar2 "param 2     " pos:[23,156] width:101 height:16 range:[0,255,0] type:#integer
	spinner nvcpar3 "param 3     " pos:[23,176] width:101 height:16 range:[0,255,255] type:#integer
	spinner nvcpar4 "param 4     " pos:[23,196] width:101 height:16 range:[0,255,255] type:#integer
	GroupBox grp1 "" pos:[8,97] width:126 height:129
	dropdownList etype "" pos:[9,235] width:125 height:21 items:#("type 1", "type 2")		
	checkbox multi "multiobject export" pos:[16,53] width:110 height:19 checked:true
	checkbox glight "geometry light" pos:[16,74] width:110 height:19 checked:true
	
on exp pressed do (
if $ == undefined then messageBox "no object selected"
else if multi.checked then (
 obj = selection as array
 dir = getSavePath caption:"select export path"
 if dir!=undefined do (
 --if obj.count==0 then messageBox "no object selected"
 --else (
 createDialog Export_prog 220 60

 for i = 1 to obj.count do 
  if obj[i].parent == undefined then (
  Export_prog.prog_all.value = i*100/obj.count --80/(NumF-i+1) + 20
  fname = dir + "\\" + obj[i].name + ".dff" --"D:\\SA_MOD\\test\\test_obj2.dff"
  Export_prog.title = obj[i].name + ",  " + (obj[i].mesh.numfaces as string) + " faces"
  f = fopen fname "wb"
  if f!=undefined then (
     DFFexport f obj[i] true havenvc.checked [nvcpar1.value,nvcpar2.value,nvcpar3.value,nvcpar4.value] false \
                        glight.checked etype.selection
     fclose f
     format "%.dff exported\n" obj[i].name
  )
  else (
        sssss = "can't create " + obj[i].name +".dff\n"
	    format "---------------------------------------->  %\n" sssss
	    messagebox sssss
       )
  ) -- i loop
  else format "obj: % have parent object\n" obj[i].name

DestroyDialog Export_prog
-- ) -- obj.count>0
) -- dir!=undef)
) ----------------------------------------   if non multi
else (
 obj = selection[1]
 if obj.parent != undefined then messagebox "object have paren object"
 else (
 fname = getSaveFileName caption:"export DFF" types:"GTA model|*.dff|"
  if fname != undefined then (
   createDialog Export_prog 220 60
   Export_prog.prog_all.value = 100
   if superClassOf obj == GeometryClass then 
                 Export_prog.title = obj.name + ",  " + (obj.mesh.numfaces as string) + " faces"
				  else
				   Export_prog.title = obj.name
   f = fopen fname "wb"
   if f!=undefined then (
      DFFexport f obj true havenvc.checked [nvcpar1.value,nvcpar2.value,nvcpar3.value,nvcpar4.value] false \
                     glight.checked etype.selection
      fclose f
      format "%.dff exported\n" obj.name
   )
   else (
         sssss = "can't create " + obj.name +".dff\n"
	     format "---------------------------------------->  %\n" sssss
	     messagebox sssss
        )
  
   DestroyDialog Export_prog

 ) -- if fname
 ) -- have parent
) -- not multi

) -- pressed

) -- rollout


try (closeRolloutFloater dffexport_flo) catch () 
dffexport_flo = newRolloutFloater "" 150 300 20 130 
addRollout  dffexport_rol dffexport_flo