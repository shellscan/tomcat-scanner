<%@page import="java.util.*" %>
<%@page import="org.apache.catalina.core.ApplicationContext" %>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="java.io.File" %>
<%@ page import="org.apache.catalina.core.StandardService" %>
<%@ page import="org.apache.catalina.connector.Connector" %>
<%@page import="java.util.*" %>
<%@ page import="com.sun.org.apache.bcel.internal.classfile.JavaClass" %>
<%@ page import="com.sun.org.apache.bcel.internal.Repository" %>
<%@ page import="java.io.FileOutputStream" %>
<%--
  Tomcat中Connector扫描
  User: wufenglin
  Date: 2022/7/25
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
            String path = getPath(req, "ConnectorScan.jsp");
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


    //获取Connector的port，防止该方法的实现被修改导致报错，单独抓取异常
    public Integer getPort(Connector connector) {
        int port;
        try {
            port = connector.getPort();
        } catch (Exception e) {
            port = -999;
        }
        return port;
    }

    //获取Connector的localPort，防止方法的实现被修改导致报错，单独抓取异常
    public Integer getLocalPort(Connector connector) {
        int localPort;
        try {
            localPort = connector.getLocalPort();
        } catch (Exception e) {
            localPort = -999;
        }
        return localPort;
    }

%>

<%
    //获取待删除的filter名，并判断是否执行删除操作
    String delConnectorHash = request.getParameter("delConnectorHash");
    String dumpConnectorHash = request.getParameter("dumpConnectorHash");

    String path = getPath(request, "ConnectorScan.jsp");
    path = path.replaceAll("\\\\", "\\\\\\\\");

    //获取StandardService
    StandardService standardService = geStandardService(request);

    //获取Connector
    Connector[] connectors = standardService.findConnectors();
    //用hash做唯一标识，用来删除对应的Connector
    Map<Integer, Connector> connectorMap = new HashMap<>();
    for (Connector connector : connectors) {
        connectorMap.put(connector.hashCode(), connector);
    }

    //删除Connector
    if (null != delConnectorHash) {
        int hash = Integer.parseInt(delConnectorHash);
        Connector connector = connectorMap.get(hash);
        if (null != connector) {
            standardService.removeConnector(connector);
            connectorMap.remove(hash);
            connectors = standardService.findConnectors();
        }
    }

    //dump
    if (null != dumpConnectorHash) {
        int hash = Integer.parseInt(dumpConnectorHash);
        Connector connector = connectorMap.get(hash);
        if (null != connector) {
            dumpClass(connector.getClass().toString().substring(6), request);
        }
    }
%>

<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tomcat-Connector列表</title>
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
            <h1>Tomcat-Connector列表</h1>
        </div>
        <table class="table">
            <tr class="table-header">
                <th>类</th>
                <th>Port</th>
                <th>LocalPort</th>
                <th>操作</th>
            </tr>
            <%
                for (int i = 0; i < connectors.length; ++i) {

            %>
            <tr class="table-safe">
                <td style="text-align: left;font-family: 'consolas';"><%=connectors[i].getClass() %>
                </td>
                <td><%=getPort(connectors[i]) %>
                </td>
                <td><%=getLocalPort(connectors[i]) %>
                </td>
                </td>
                <td>
                    <button class="button" onclick="delConnector('<%=connectors[i].hashCode()%>')">delete</button>
                    <button class="button" onclick="dumpConnector('<%=connectors[i].hashCode()%>')">dump</button>
                </td>
            </tr>
            <%
                }
            %>
        </table>

        <form id="delConnectorForm" action="" method="get" style="display: none;">
            <input id="delConnectorHash" name="delConnectorHash">
        </form>
        <form id="dumpConnectorForm" action="" method="get" style="display: none;">
            <input id="dumpConnectorHash" name="dumpConnectorHash">
        </form>
    </div>
</div>
</body>
<script type="text/javascript">
function delConnector(hash){
	var msg = "确认删除吗?"
	if (confirm(msg)) {
		document.getElementById("delConnectorHash").value = hash
		document.getElementById("delConnectorForm").submit()
	}
}
function dumpConnector(hash){
    var path = '<%=path%>'
    var msg = "dump出的文件存放在" + path + "目录中"
    alert(msg)
	document.getElementById("dumpConnectorHash").value = hash
	document.getElementById("dumpConnectorForm").submit()
}
</script>
</html>