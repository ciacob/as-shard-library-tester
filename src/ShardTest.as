package {

    /**
     * ShardTest class provides a set of unit tests for the Shard library.
     * It includes tests for hierarchy, content, cloning, identity, linkage,
     * queries, traversal, and finding elements within a shard structure.
     */
    public class ShardTest {

        import com.github.ciacob.asshardlibrary.Shard;
        import com.github.ciacob.asshardlibrary.IShard;

        public function ShardTest() {
        }

        /**
         * Test results storage.
         */
        private const _results:Object = {pass: [],
                fail: []};

        /**
         * Registers a passing test result.
         * @param info Description of the test.
         * @param result Actual result of the test.
         * @param expectedResult Expected result of the test.
         */
        private function _registerPassResult(info:String, result:*, expectedResult:*):void {
            _results.pass.push({info: info,
                    result: result,
                    expectedResult: expectedResult});
        }

        /**
         * Registers a failing test result.
         * @param info Description of the test.
         * @param result Actual result of the test.
         * @param expectedResult Expected result of the test.
         */
        private function _registerFailResult(info:String, result:*, expectedResult:*):void {
            _results.fail.push({info: info,
                    result: result,
                    expectedResult: expectedResult});
        }

        /**
         * Runs a test with the given info, injected data provider, and an expected
         * result or validator.
         *
         * @param   info
         *          Description of the test.
         *
         * @param   provider
         *          Function to obtain a finite value that will be subjected to testing.
         *          Expects no arguments and can return any value.
         *
         * @param   expected
         *          Expected result of the test. Can be a value or a function.
         *          If a value is provided, it must match exactly the result of
         *          `provider()` for the test to pass.
         *          If a function is provided, it will be called with the result of
         *          `provider()` and must actually decide whether the test passed or failed
         *          by returning `true` or `false`.
         *
         * @return  Returns `true` if the test passed, `false` otherwise.
         */
        public function test(info:String, provider:Function, expected:*):Boolean {
            var valueToTest:* = provider();
            var testPassed:Boolean = false;

            // If `expected` is a function, call it with the result.
            if (expected is Function) {
                testPassed = expected(valueToTest);
            } else {
                // Otherwise, compare the value directly
                testPassed = (valueToTest === expected);
            }
            if (testPassed) {
                _registerPassResult(info, valueToTest, expected);
                trace("[PASS] " + info);
                return true;
            } else {
                _registerFailResult(info, valueToTest, expected);
                trace("[FAIL] " + info + " - Expected: " + expected + ", Got: " + valueToTest);
                return false;
            }
        }

        /**
         * Runs all tests in the ShardTest class.
         * Outputs the results to the console.
         */
        public function run():void {
            testHierarchy();
            testCircularityEnforcement();
            testContent();
            testCloneAndDelete();
            testIdentityAndLinkage();
            testQueries();
            testTraversal();
            testFind();

            trace('--------------------');
            trace('Results:');
            trace('Passed: ' + _results.pass.length);
            trace('Failed: ' + _results.fail.length);
            if (_results.fail.length > 0) {
                trace('Failures:');
                for each (var fail:Object in _results.fail) {
                    trace(' - ' + fail.info + ' | Expected: ' + fail.expectedResult + ', Got: ' + fail.result);
                }
            } else {
                trace('ALL TESTS PASSED!');
            }
        }

        /**
         * Tests the hierarchy of Shard objects.
         * It checks the index, route, and number of children in a hierarchy.
         */
        private function testHierarchy():void {
            const root:Shard = new Shard();
            const a:Shard = new Shard();
            const b:Shard = new Shard();
            const c:Shard = new Shard();

            root.addChild(a);
            root.addChild(b);
            b.addChild(c);

            test("[Hierarchy] a.index", function():* {
                return a.findIndex();
            }, 0);
            test("[Hierarchy] c.route", function():* {
                return c.findRoute();
            }, "-1_1_0");
            test("[Hierarchy] root.num", function():* {
                return root.findNumChildren();
            }, 2);
        }

        /**
         * Tests the enforcement of circularity in Shard objects.
         * It checks various scenarios where circular references could occur,
         * ensuring that they are handled correctly.
         */
        private function testCircularityEnforcement():void {
            const root:Shard = new Shard();
            const a:Shard = new Shard();
            const b:Shard = new Shard();
            const c:Shard = new Shard();

            // Build: root → a → b
            root.addChild(a);
            a.addChild(b);

            // ✅ Positive test: Adopt cousin
            // Create: root → a → b
            //                      ↘ c (currently orphan)
            test("[Circularity] Adopt unrelated (cousin) node", function():* {
                b.addChild(c); // should succeed
                return c.parent === b;
            }, true);

            // ❌ Negative test 1: Attempt to add self as child
            test("[Circularity] Cannot add self as child", function():* {
                a.addChild(a); // should be silently ignored
                return a.parent !== a;
            }, true);

            // ❌ Negative test 2: Attempt to add direct parent
            test("[Circularity] Cannot add parent as child", function():* {
                b.addChild(a); // should be ignored
                return a.parent !== b;
            }, true);

            // ❌ Negative test 3: Attempt to add grandparent
            test("[Circularity] Cannot add grandparent as child", function():* {
                c.addChild(root); // should be ignored
                return root.parent !== c;
            }, true);

            // ✅ Positive test: Reattach orphaned node
            b.deleteChild(c);
            root.addChild(c); // should succeed
            test("[Circularity] Reattach detached node", function():* {
                return c.parent === root;
            }, true);
        }


        /**
         * Tests the content of Shard objects.
         * It checks the label and active state of a Shard.
         */
        private function testContent():void {
            const node:Shard = new Shard();
            node.$set("label", "Test");
            node.$set("active", true);

            test("[Content] label", function():* {
                return node.$get("label");
            }, "Test");
            test("[Content] has 'foo'", function():* {
                return node.has("foo");
            }, false);
        }

        /**
         * Tests cloning and deleting Shard objects.
         * It checks the child count before and after cloning and deleting a child.
         */
        private function testCloneAndDelete():void {
            const root:Shard = new Shard();
            const a:Shard = new Shard();
            const b:Shard = new Shard();
            root.addChild(a);
            a.addChild(b);

            const clone:Shard = root.clone(true) as Shard;

            test("[Clone] original child count", function():* {
                return root.findNumChildren();
            }, 1);
            test("[Clone] clone child count", function():* {
                return clone.findNumChildren();
            }, 1);

            root.deleteChild(a);
            test("[Delete] after delete, child count", function():* {
                return root.findNumChildren();
            }, 0);
        }

        /**
         * Tests the identity and linkage of Shard objects.
         * It checks the ID, parent-child relationships, and level of Shard objects.
         */
        private function testIdentityAndLinkage():void {
            const root:Shard = new Shard();
            const a:Shard = new Shard();
            const b:Shard = new Shard();

            root.addChild(a);
            root.addChild(b);

            test("[Link] a.id", function():* {
                return a.id;
            }, function(testVal:*):Boolean {
                var uuidPattern:RegExp = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
                return (testVal && (testVal is String) && testVal.length == 36 && uuidPattern.test(testVal));
            });
            test("[Link] a.parent === root", function():* {
                return a.parent === root;
            }, true);
            test("[Link] b.prev === a", function():* {
                return b.prev === a;
            }, true);
            test("[Link] a.next === b", function():* {
                return a.next === b;
            }, true);
            test("[Link] root.firstChild === a", function():* {
                return root.firstChild === a;
            }, true);
            test("[Link] root.lastChild === b", function():* {
                return root.lastChild === b;
            }, true);
            test("[Link] a.level", function():* {
                return a.findLevel();
            }, 1);
            test("[Link] root.level", function():* {
                return root.findLevel();
            }, 0);
            test("[Link] b.findRoot() === root", function():* {
                return b.findRoot() === root;
            }, true);
        }

        /**
         * Tests various queries on Shard objects.
         * It checks finding by route, cloning, and identity checks.
         */
        private function testQueries():void {
            const root:Shard = new Shard();
            const a:Shard = new Shard();
            const b:Shard = new Shard();
            root.addChild(a);
            a.addChild(b);

            const route:String = b.findRoute();
            const found:IShard = root.getByRoute(route);
            test("[Route] found === b", function():* {
                return found === b;
            }, true);

            const clone:IShard = root.clone(true);
            test("[isSame] clone.isSame(root)", function():* {
                return clone.isSame(root);
            }, true);

            test("[isLike] clone.isLike(root)", function():* {
                return clone.isLike(root);
            }, true);
        }

        /**
         * Tests the traversal methods of Shard objects.
         * It checks all, descendants, parents, children, siblings, and their reverse methods.
         */
        private function testTraversal():void {
            const root:Shard = new Shard();
            const a:Shard = new Shard();
            const b:Shard = new Shard();
            const c:Shard = new Shard();

            root.addChild(a);
            a.addChild(b);
            a.addChild(c);

            trace("[All]");
            test('all', function():* {
                const allElements:Array = [];
                root.all(function(el:IShard, $break:Function):void {
                    allElements.push(el.findRoute());
                    trace(" -", el.toString());
                });
                return allElements.toString();
            }, '-1,-1_0,-1_0_0,-1_0_1');

            trace("[Descendants of a]");
            test('Descendants of a', function():* {
                const descendants:Array = [];
                a.descendants(function(el:IShard, $break:Function):void {
                    descendants.push(el.findRoute());
                    trace(" ->", el.toString());
                });
                return descendants.toString();
            }, '-1_0_0,-1_0_1');

            trace("[Parents of b]");
            test('Parents of b', function():* {
                const parents:Array = [];
                b.parents(function(el:IShard, $break:Function):void {
                    parents.push(el.findRoute());
                    trace(" <-", el.toString());
                });
                return parents.toString();
            }, '-1_0,-1');

            trace("[Children of a]");
            test('Children of a', function():* {
                const children:Array = [];
                a.children(function(el:IShard, $break:Function):void {
                    children.push(el.findRoute());
                    trace(" *", el.toString());
                });
                return children.toString();
            }, '-1_0_0,-1_0_1');

            trace("[ChildrenReverse of a]");
            test('ChildrenReverse of a', function():* {
                const childrenReverse:Array = [];
                a.childrenReverse(function(el:IShard, $break:Function):void {
                    childrenReverse.push(el.findRoute());
                    trace(" ^", el.toString());
                });
                return childrenReverse.toString();
            }, '-1_0_1,-1_0_0');

            trace("[Siblings of b]");
            test('Siblings of b', function():* {
                const siblings:Array = [];
                b.siblings(function(el:IShard, $break:Function):void {
                    siblings.push(el.findRoute());
                    trace(" >", el.toString());
                });
                return siblings.toString();
            }, '-1_0_1');

            trace("[SiblingsReverse of c]");
            test('SiblingsReverse of c', function():* {
                const siblingsReverse:Array = [];
                c.siblingsReverse(function(el:IShard, $break:Function):void {
                    siblingsReverse.push(el.findRoute());
                    trace(" <", el.toString());
                });
                return siblingsReverse.toString();
            }, '-1_0_0');
        }

        /**
         * Tests finding elements within a Shard structure.
         * It checks finding by ID, key, and custom function.
         */
        private function testFind():void {
            const root:Shard = new Shard();
            const a:Shard = new Shard();
            a.$set("type", "target");
            const b:Shard = new Shard();
            b.$set("type", "other");
            root.addChild(a);
            root.addChild(b);

            var matches:Vector.<IShard> = root.find(a.id);
            test("[Find by id] found", function():* {
                return matches.length;
            }, 1);

            matches = root.find("target", "type");
            test("[Find by key] type='target'", function():* {
                return matches.length;
            }, 1);

            matches = root.find("target", function(shard:IShard, what:*, $break:Function):Boolean {
                if (shard.has("type") && shard.$get("type") === what) {
                    return true;
                }
                return false;
            });
            test("[Find by fn] type='target'", function():* {
                return matches.length;
            }, 1);
        }

    }
}
