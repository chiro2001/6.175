## 2023-06-23

### 函数式编程与副作用

把副作用（修改状态操作）记录下来，执行的时候再执行（再改变状态）。

尽可能后推状态改变的时间（Compose 组合），如 IO 操作。

例如：

```bsv
Server#(Coord, Coord) m <- mkTransformer;
```

“创建模块”是一种副作用。

Bluespec 中用 `method` 和 `ActionMethod` 区分是否有副作用，不过它并不是纯的函数式编程。

Clash 与 Bluespec 类似，但是是标准的函数式编程，可以将副作用完全 delay。

与函数式编程语言的 `lazy` 有点像，但是是不一样的。`lazy` 可以表达无限数据结构，没用到的不会被计算。

### Rule 与 Conflict Matrix

Conflict Matrix 是一种对电路的建模方式。

在思考代码逻辑正确性的时候可以假定每次只执行一条 Rule，则 Conflict Matrix 可以保证多个 Rules 并行执行过程中不会出现冲突。

将并行转换为串行逻辑来思考。

### Maybe

Maybe#() 是一个容器，用一个 Tag 标志内容，也是一个 **Monad**。

加入容器：tagged Invalid / Valid(...)

打开容器：`fromMaybe`