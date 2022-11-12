import macros                                                                   # Los MACROS nos permiten acceso de lectura/escritura al AST

var mensaje: string = "Hola mundo!"                                             # Definimos una variable con valor "Hola mundo" de tipo string
echo mensaje                                                                    # Mandamos la variable al std output

# Definimos una clase Persona, de la cual heredan las clases Ingeniero y Licenciado
# usando la sintaxis estandar de nim.

# type Persona = ref object of RootObj
#   nombre: string
#   edad: int
# method vocalize(self: Persona): string {.base.} = "..."
# method edadAnios(self: Persona): int {.base.} = self.edad

# type Ingeniero = ref object of Persona
# method vocalize(self: Ingeniero): string = "Soy mejor"
# method edadAnios(self: Ingeniero): int = self.edad + 7

# type Licenciado = ref object of Persona
# method vocalize(self: Licenciado): string = "Quiero ser ing..."


# Esta sintaxis es repetitiva y poco legible. Podemos mejorarla usando MACROS para 
# modificar el AST y que reconozca una sintaxis como la siguiente:
#  class Persona of RootObj:
#   var nombre: string
#   var edad: int
#   method vocalize: string = "..."
#   method edadAnios: int = self.age  # `self` is injected

# class Ingeniero of Persona:
#   method vocalize: string = "Soy mejor"
#   method edadAnios: int = self.age + 7

# class Licenciado of Persona:
#   method vocalize: string = "Quiero ser ing..."





macro class*(head, body: untyped): untyped =
  var typename, baseName: NimNode
  var isExported: bool

  if head.kind == nnkInfix and eqIdent(head[0], "of"):
    typeName = head[1]
    baseName = head[2]

  elif head.kind == nnkInfix and eqIdent(head[0], "*") and
       head[2].kind == nnkPrefix and eqIdent(head[2][0], "of"):
    typeName = head[1]
    baseName = head[2][1]
    isExported = true

  else:
    error "Nodo inválido: " & head.lispRepr
  result = newStmtList()
  template typeDecl(a, b): untyped =
    type a = ref object of b

  template typeDeclPub(a, b): untyped =
    type a* = ref object of b

  if isExported:
    result.add getAst(typeDeclPub(typeName, baseName))
  else:
    result.add getAst(typeDecl(typeName, baseName))

  echo treeRepr(body)

  var recList = newNimNode(nnkRecList)

  let ctorName = newIdentNode("new" & $typeName)

  for node in body.children:
    case node.kind:

    of nnkMethodDef, nnkProcDef:
      if node.name.kind != nnkAccQuoted and node.name.basename == ctorName:
        node.params[0] = typeName
      else:
        node.params.insert(1, newIdentDefs(ident("self"), typeName))
      result.add(node)

    of nnkVarSection:
      for n in node.children:
        recList.add(n)

    else:
      result.add(node)

  result[0][0][2][0][2] = recList

class Persona of RootObj:
  var nombre: string
  var edad: int
  method vocalize: string {.base.} = "..."
  method edadAnios: int {.base.} = self.edad
  proc `$`: string = "Persona:" & self.nombre & ":" & $self.edad

class Ingeniero of Persona:
  method vocalize: string = "Soy " & self.nombre & " y soy ing."
  method edadAnios: int = self.edad
  proc `$`: string = "Ing. " & self.nombre & ":" & $self.edad

class Licenciado of Persona:
  method vocalize: string = "Soy " & self.nombre & " y quiero ser ing..."
  proc `$`: string = "Lic. " & self.nombre & ":" & $self.edad

# ---------------------------------------------------------------------------------

var gente: seq[Persona] = @[]
gente.add(Ingeniero(nombre: "Marco", edad: 23))
gente.add(Licenciado(nombre: "Jose", edad: 21))

for a in gente:
  echo a.vocalize()
  echo a.edadAnios()
