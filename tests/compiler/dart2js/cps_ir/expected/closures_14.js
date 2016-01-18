// Expectation for test: 
// class Foo {
//   get getter {
//     print('getter');
//     return (x) => x;
//   }
// }
// main(x) {
//   var notTearOff = new Foo().getter;
//   print(notTearOff(123));
//   print(notTearOff(321));
// }

function(x) {
  var notTearOff = new V.Foo_getter_closure();
  V.Foo$();
  P.print("getter");
  P.print(notTearOff.call$1(123));
  P.print(notTearOff.call$1(321));
}
