<%@page import="java.util.Map.Entry" %>
<%@page import="java.util.LinkedHashMap" %>
<%@page import="java.util.*" %>
<%@page import="org.apache.catalina.core.StandardContext" %>
<%@page import="org.apache.catalina.core.ApplicationContext" %>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="java.io.File" %>
<%@ page import="com.sun.org.apache.bcel.internal.classfile.JavaClass" %>
<%@ page import="com.sun.org.apache.bcel.internal.Repository" %>
<%@ page import="java.io.FileOutputStream" %>
<%@ page import="org.apache.catalina.core.StandardService" %>
<%@ page import="org.apache.catalina.Server" %>
<%@ page import="org.apache.catalina.LifecycleListener" %>
<%--
  Tomcat中Listener扫描

  User: wufenglin
  Date: 2022/7/19
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%!
    //自定义ListenerBean
    class ListenerBean {
        // filter名
        private String listenerName;
        // listener对象
        private Object listenerObject;

        public ListenerBean(String listenerName, Object listenerObject) {
            this.listenerName = listenerName;
            this.listenerObject = listenerObject;
        }

        public String getListenerName() {
            return listenerName;
        }

        public Object getListenerObject() {
            return listenerObject;
        }
    }

    //获得StandardContext
    public StandardContext getStandardContext(HttpServletRequest request) throws Exception {

        ApplicationContext applicationContext = getApplicationContext(request);

        //获取StandardContext
        Field context = applicationContext.getClass().getDeclaredField("context");
        context.setAccessible(true);
        return (StandardContext) context.get(applicationContext);
    }

    //获得ApplicationContext
    public ApplicationContext getApplicationContext(HttpServletRequest request) throws Exception {
        ServletContext servletContext = request.getSession().getServletContext();
        Field appctx = servletContext.getClass().getDeclaredField("context");
        appctx.setAccessible(true);
        return (ApplicationContext) appctx.get(servletContext);
    }

    //获得StandardService
    public StandardService geStandardService(HttpServletRequest request) throws Exception {

        ApplicationContext applicationContext = getApplicationContext(request);
        Field service = applicationContext.getClass().getDeclaredField("service");
        service.setAccessible(true);
        return (StandardService) service.get(applicationContext);
    }

    //获取当前路径
    public String getPath(HttpServletRequest req, String filename) {
        String path = req.getSession().getServletContext().getRealPath(filename);
        return path.substring(0, path.lastIndexOf(File.separator));
    }

    //dump class
    public void dumpClass(String className, HttpServletRequest req) {
        try {
            JavaClass javaClass = Repository.lookupClass(Class.forName(className));
            String path = getPath(req, "ListenerScan.jsp");
            String simpleClassName = className.substring(className.lastIndexOf(".") + 1, className.length());
            FileOutputStream fos = new FileOutputStream(new File(path + File.separator + simpleClassName + ".dump"));
            javaClass.dump(fos);
        } catch (NullPointerException ne) {
            req.setAttribute("errmsg", "dump class 失败");

        } catch (ClassNotFoundException cfe) {
            req.setAttribute("errmsg", "dump class 失败");
        } catch (Exception e) {
        }
    }
%>

<%
    //获取待删除的filter名，并判断是否执行删除操作
    String delListener = request.getParameter("delFilterName");
    String dumpListener = request.getParameter("dumpListenerName");
    String path = getPath(request, "ListenerScan.jsp");
    path = path.replaceAll("\\\\", "\\\\\\\\");
    boolean runDump = dumpListener != null && !"".equals(dumpListener);
    boolean runDel = delListener != null && !"".equals(delListener);
    //Listener列表
    LinkedHashMap<String, ListenerBean> listenerMap = new LinkedHashMap<>();
    LinkedHashMap<String, ListenerBean> lifecycleListenerMap = new LinkedHashMap<>();
    LinkedHashMap<String, ListenerBean> serverListenerMap = new LinkedHashMap<>();


    //获取StandardContext
    StandardContext standardContext = getStandardContext(request);
    //获取Server
    StandardService standardService = geStandardService(request);
    Server server = standardService.getServer();

    //获取EventListener
    Object[] applicationEventListeners = standardContext.getApplicationEventListeners();
    //获取LifecycleListener
    Object[] applicationLifecycleListeners = standardContext.getApplicationLifecycleListeners();
    //获取Server中的Listener
    LifecycleListener[] serverListeners = server.findLifecycleListeners();


    Object o = serverListeners[0];
    LifecycleListener s = (LifecycleListener) o;


    for (Object applicationEventListener : applicationEventListeners) {
        listenerMap.put(applicationEventListener.toString(), new ListenerBean(applicationEventListener.toString(), applicationEventListener));
    }
    for (Object applicationLifecycleListener : applicationLifecycleListeners) {
        lifecycleListenerMap.put(applicationLifecycleListener.toString(), new ListenerBean(applicationLifecycleListener.toString(), applicationLifecycleListener));
    }
    for (LifecycleListener serverListener : serverListeners) {
        serverListenerMap.put(serverListener.toString(), new ListenerBean(serverListener.toString(), serverListener));
    }

    //删除指定Listener
    if (runDel) {
        if (null != listenerMap.get(delListener)) {
            listenerMap.remove(delListener);
            ArrayList<Object> listener = new ArrayList<>();
            for (Entry<String, ListenerBean> entry : listenerMap.entrySet()) {
                listener.add(entry.getValue().getListenerObject());
            }
            standardContext.setApplicationEventListeners(listener.toArray());
        } else if (null != lifecycleListenerMap.get(delListener)) {
            lifecycleListenerMap.remove(delListener);
            ArrayList<Object> listener = new ArrayList<>();
            for (Entry<String, ListenerBean> entry : lifecycleListenerMap.entrySet()) {
                listener.add(entry.getValue().getListenerObject());
            }
            standardContext.setApplicationLifecycleListeners(listener.toArray());
        } else if (null != serverListenerMap.get(delListener)) {
            server.removeLifecycleListener((LifecycleListener) serverListenerMap.get(delListener).getListenerObject());
            serverListenerMap.remove(delListener);
        }
    }

    if (runDump) {
        dumpClass(dumpListener.substring(0, dumpListener.indexOf("@")), request);
    }

%>

<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tomcat-Listener列表</title>
    <style>
        .body {
            width: 100%;
            margin: 0 auto;
            font-family: "consolas";
            background-color: #DCDCDC;
        }

        .content {
            width: 100%;
            margin-top: 50px;
        }

        .title {
            text-align: center;
        }

        .table {
            width: 80%;
            margin: 0 auto;
            border-radius: 4px;
            padding: 5px;
        }

        .table-header {
            text-align: center;
        }

        .table-header th {
            border: 2px solid #000000;
            border-radius: 1px;
        }

        .table-safe td {
            border: 2px solid #000000;
            border-radius: 1px;
        }

        .table-safe {
            text-align: center;
        }
		.button{
			font-size: medium;
			text-decoration: underline;
		}
		.button:hover {
			color: #6495ED;
			cursor: pointer;
		}
    </style>
</head>
<body class="body">
<script type="text/javascript">
		var message = "慎重执行删除操作！！！删除操作不可逆，如果删除了正常的内容后想恢复，则需要重启OA。"
		alert(message)
</script>
<div class="content">
    <div class="">
        <div class="title">
            <h1>Tomcat-Listener列表</h1>
        </div>
        <table class="table">
            <tr class="table-header">
                <th>Listener</th>
                <th>操作</th>
            </tr>
            <%
                for (Map.Entry<String, ListenerBean> entry : listenerMap.entrySet()) {
                    ListenerBean listener = entry.getValue();
            %>
            <tr class="table-safe">
                <td style="text-align: left;font-family: 'consolas';"><%=listener.getListenerName() %>
                </td>
                <td>
                    <button class="button" onclick="delListener('<%=listener.getListenerName()%>')">delete</button>
                    <button class="button" onclick="dumpListener('<%=listener.getListenerName()%>')">dump</button>
                </td>
            </tr>
            <%
                }
            %>
            <%
                for (Map.Entry<String, ListenerBean> entry : lifecycleListenerMap.entrySet()) {
                    ListenerBean listener = entry.getValue();
            %>
            <tr class="table-safe">
                <td style="text-align: left;font-family: 'consolas';"><%=listener.getListenerName() %>
                </td>
                <td>
                    <button class="button" onclick="delListener('<%=listener.getListenerName()%>')">delete</button>
                    <button class="button" onclick="dumpListener('<%=listener.getListenerName()%>')">dump</button>
                </td>
            </tr>
            <%
                }
            %>
            <%
                for (Map.Entry<String, ListenerBean> entry : serverListenerMap.entrySet()) {
                    ListenerBean listener = entry.getValue();
            %>
            <tr class="table-safe">
                <td style="text-align: left;font-family: 'consolas';"><%=listener.getListenerName() %>
                </td>
                <td>
                    <button class="button" onclick="delListener('<%=listener.getListenerName()%>')">delete</button>
                    <button class="button" onclick="dumpListener('<%=listener.getListenerName()%>')">dump</button>
                </td>
            </tr>
            <%
                }
            %>

        </table>

        <form id="delListenerForm" action="" method="get" style="display: none;">
            <input id="delListenerName" name="delFilterName">
        </form>
        <form id="dumpListenerForm" action="" method="get" style="display: none;">
            <input id="dumpListenerName" name="dumpListenerName">
        </form>
    </div>
</div>
</body>
<script type="text/javascript">
function delListener(listenerName){
	var msg = "确认删除" + listenerName + "吗?"
	if (confirm(msg)) {
		document.getElementById("delListenerName").value = listenerName
		document.getElementById("delListenerForm").submit()
	}
}

function dumpListener(listenerName) {
    var path = '<%=path%>'
    var msg = "dump出的文件存放在" + path + "目录中"
    alert(msg)
    document.getElementById("dumpListenerName").value = listenerName
	document.getElementById("dumpListenerForm").submit()
}

</script>
</html>