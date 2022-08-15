<%@page import="java.util.*" %>
<%@page import="org.apache.catalina.core.ApplicationContext" %>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="java.io.File" %>
<%@ page import="org.apache.catalina.core.StandardService" %>
<%@page import="java.util.*" %>
<%@ page import="com.sun.org.apache.bcel.internal.classfile.JavaClass" %>
<%@ page import="com.sun.org.apache.bcel.internal.Repository" %>
<%@ page import="java.io.FileOutputStream" %>
<%@ page import="javax.websocket.server.ServerContainer" %>
<%@ page import="java.util.concurrent.ConcurrentSkipListMap" %>
<%@ page import="javax.websocket.server.ServerEndpointConfig" %>
<%--
  Tomcat中WebSocket扫描
  User: wufenglin
  Date: 2022/8/9
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%!
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

    //dump class
    public void dumpClass(String className, HttpServletRequest req) {
        try {
            JavaClass javaClass = Repository.lookupClass(Class.forName(className));
            String path = getPath(req, "WebSocketScan.jsp");
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

    //获取当前路径
    public String getPath(HttpServletRequest req, String filename) {
        String path = req.getSession().getServletContext().getRealPath(filename);
        return path.substring(0, path.lastIndexOf(File.separator));
    }
%>

<%
    //获取待删除的key
    String delWebSocketKey = request.getParameter("delWebSocketKey");
    //获取待dump的key
    String dumpWebSocketKey = request.getParameter("dumpWebSocketKey");

    String path = getPath(request, "WebSocketScan.jsp");
    path = path.replaceAll("\\\\", "\\\\\\\\");

    //获取applicationContext
    ApplicationContext applicationContext = getApplicationContext(request);
    //获取ServerContainer
    ServerContainer serverContainer = (ServerContainer) applicationContext.getAttribute(ServerContainer.class.getName());
    //反射获取ServerContainer中的变量configExactMatchMap
    Field exactField = serverContainer.getClass().getDeclaredField("configExactMatchMap");
    exactField.setAccessible(true);
    Map<String, Object> configExactMatchMap = (Map<String, Object>) exactField.get(serverContainer);

    //反射获取ServerContainer中的configTemplateMatchMap
    Field templateMatchField = serverContainer.getClass().getDeclaredField("configTemplateMatchMap");
    templateMatchField.setAccessible(true);
    Map<Integer, ConcurrentSkipListMap> configTemplateMatchMap = (Map<Integer, ConcurrentSkipListMap>) templateMatchField.get(serverContainer);

    //删除Socket
    if (null != delWebSocketKey) {
        String[] split = delWebSocketKey.split(":");
        if ("1".equals(split[0])) {
            configTemplateMatchMap.remove(Integer.parseInt(split[1]));
        } else if ("2".equals(split[0])) {
            configExactMatchMap.remove(split[1]);
        }
    }
    //通过类信息dump对应的类
    if (null != dumpWebSocketKey) {
        String[] split = dumpWebSocketKey.split(":");
        if ("1".equals(split[0])) {
            dumpClass(split[1], request);
        } else if ("2".equals(split[0])) {
            dumpClass(split[1], request);
        }
    }

%>

<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tomcat-WebSocket列表</title>
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
		var message2 = "删除WebSocket后需要中断一次才能断开已连接的Socket。"
		alert(message)
		alert(message2)
</script>
<div class="content">
    <div class="">
        <div class="title">
            <h1>Tomcat-WebSocket列表</h1>
        </div>
        <table class="table">
            <tr class="table-header">
                <th>对象信息</th>
                <th>类型</th>
                <th>映射地址</th>
                <th>操作</th>
            </tr>
            <%
                for (Map.Entry<Integer, ConcurrentSkipListMap> entry : configTemplateMatchMap.entrySet()) {
                    Integer key = entry.getKey();
                    String value = entry.getValue().toString();

                    //这里是一个ConcurrentSkipListMap的数据结构，遍历这个Map
                    ConcurrentSkipListMap<String, Object> map = entry.getValue();
                    for (Map.Entry<String, Object> entry1 : map.entrySet()) {
                        Object value1 = entry1.getValue();

                        //通过反射获取ServerEndpointConfig
                        Class<?> wsMappingResultObj = Class.forName("org.apache.tomcat.websocket.server.WsServerContainer$TemplatePathMatch");
                        Field configField = wsMappingResultObj.getDeclaredField("config");
                        configField.setAccessible(true);
                        ServerEndpointConfig config2 = (ServerEndpointConfig) configField.get(value1);
                        String clazzName = config2.getEndpointClass().toString().substring(6);
            %>
            <tr class="table-safe">
                <td style="text-align: left;font-family: 'consolas';"><%=clazzName %>
                </td>
                <td>configTemplateMatch
                </td>
                <td><%=value.substring(1, value.indexOf("=")) %>
                </td>
                </td>
                <td>
                    <button class="button" onclick="delWebSocket('<%="1:" + key%>')">delete</button>
                    <button class="button" onclick="dumpWebSocket('<%="1:" + clazzName%>')">dump</button>
                </td>
            </tr>
            <%
                    }
                }
            %>
            <%
                for (Map.Entry<String, Object> entry : configExactMatchMap.entrySet()) {
                    String key = entry.getKey();
                    Object value = entry.getValue();

                    //config存放在WsServerContainer类中的内部类ExactPathMatch的变量config中，通过反射获取该属性
                    Class<?> wsMappingResultObj = Class.forName("org.apache.tomcat.websocket.server.WsServerContainer$ExactPathMatch");
                    Field configField = wsMappingResultObj.getDeclaredField("config");
                    configField.setAccessible(true);
                    ServerEndpointConfig config1 = (ServerEndpointConfig) configField.get(value);
                    String clazzName = config1.getEndpointClass().toString().substring(6);

            %>
            <tr class="table-safe">
                <td style="text-align: left;font-family: 'consolas';"><%= clazzName %>
                </td>
                <td>configExactMatch
                </td>
                <td><%=key %>
                </td>
                </td>
                <td>
                    <button class="button" onclick="delWebSocket('<%="2:" + key%>')">delete</button>
                    <button class="button" onclick="dumpWebSocket('<%="2:" + clazzName%>')">dump</button>
                </td>
            </tr>
            <%
                }
            %>
        </table>

        <form id="delWebSocketForm" action="" method="get" style="display: none;">
            <input id="delWebSocketKey" name="delWebSocketKey">
        </form>
        <form id="dumpWebSocketForm" action="" method="get" style="display: none;">
            <input id="dumpWebSocketKey" name="dumpWebSocketKey">
        </form>
    </div>
</div>
</body>
<script type="text/javascript">
function delWebSocket(key){
	var msg = "确认删除吗?"
	if (confirm(msg)) {
		document.getElementById("delWebSocketKey").value = key
		document.getElementById("delWebSocketForm").submit()
	}
}
function dumpWebSocket(key){
    var path = '<%=path%>'
    var msg = "dump出的文件存放在" + path + "目录中"
    alert(msg)
	document.getElementById("dumpWebSocketKey").value = key
	document.getElementById("dumpWebSocketForm").submit()
}

</script>
</html>