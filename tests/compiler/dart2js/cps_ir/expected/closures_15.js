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
// }

function(x) {
  V.Foo$();
  P.print("getter");
  P.print(123);
}
