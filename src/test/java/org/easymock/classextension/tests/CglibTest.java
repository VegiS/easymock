/**
 * Copyright 2003-2009 OFFIS, Henri Tremblay
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.easymock.classextension.tests;

import java.lang.reflect.Method;
import java.util.ArrayList;

import junit.framework.TestCase;
import net.sf.cglib.proxy.*;

import org.easymock.classextension.internal.ClassInstantiatorFactory;
import org.junit.Test;

/**
 * This test case is used to make sure that the way cglib is used is providing
 * the expected behavior
 */
public class CglibTest extends TestCase {

    /**
     * Check that an interceptor is used by only one instance of a class
     * 
     * @throws Exception
     */
    @Test
    public void test() throws Exception {

        Factory f1 = createMock();
        Factory f2 = createMock();

        assertNotSame(f1.getCallback(0), f2.getCallback(0));
    }

    private Factory createMock() throws Exception {
        MethodInterceptor interceptor = new MethodInterceptor() {
            public Object intercept(Object obj, Method method, Object[] args,
                    MethodProxy proxy) throws Throwable {
                return proxy.invokeSuper(obj, args);
            }
        };

        Enhancer enhancer = new Enhancer();
        enhancer.setSuperclass(ArrayList.class);
        enhancer.setCallbackType(MethodInterceptor.class);

        Class<?> mockClass = enhancer.createClass();

        Enhancer.registerCallbacks(mockClass, new Callback[] { interceptor });

        Factory f = (Factory) ClassInstantiatorFactory.getInstantiator()
                .newInstance(mockClass);

        f.getCallback(0);

        return f;
    }
}