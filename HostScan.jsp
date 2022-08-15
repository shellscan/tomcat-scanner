<%@ page import="org.apache.catalina.core.ApplicationContext" %>
<%@ page import="java.lang.reflect.Field" %>
<%@ page import="java.io.File" %>
<%@ page import="org.apache.catalina.core.*" %>
<%@ page import="com.sun.org.apache.bcel.internal.classfile.JavaClass" %>
<%@ page import="com.sun.org.apache.bcel.internal.Repository" %>
<%@ page import="java.io.FileOutputStream" %>
<%@ page import="org.apache.catalina.Container" %>
<%@ page import="java.util.HashMap" %>

<%--
  Tomcat中HostScan扫描

  User: wufenglin
  Date: 2022/8/15
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

    //获得StandardContext
    public StandardContext getStandardContext(HttpServletRequest request) throws Exception {

        ApplicationContext applicationContext = getApplicationContext(request);

        //获取StandardContext
        Field context = applicationContext.getClass().getDeclaredField("context");
        context.setAccessible(true);
        return (StandardContext) context.get(applicationContext);
    }

    //获取engine
    public StandardEngine getEngine(StandardContext context){
        return (StandardEngine)context.getParent().getParent();
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
%>
<%
    //获取待删除的filter名，并判断是否执行删除操作
    String delHost = request.getParameter("delHostHash");
    String dumpHost = request.getParameter("dumpHostHash");

    String path = getPath(request, "ConnectorScan.jsp");
    path = path.replaceAll("\\\\", "\\\\\\\\");


    //获取StandardContext
    StandardContext standardContext = getStandardContext(request);

    //获取engine
    StandardEngine engine = getEngine(standardContext);

    //hostMap用于存储所有的host
    HashMap<Integer, Container> hostMap = new HashMap<>();

    //获得所有host
    Container[] hostChildren = engine.findChildren();
    for (Container hostChild : hostChildren) {
        //存到Map中，key为hash
        hostMap.put(hostChild.hashCode(), hostChild);
    }


    //删除Host
    if (null != delHost) {
        int hash = Integer.parseInt(delHost);
        Container host = hostMap.get(hash);
        if (null != host) {
            engine.removeChild(host);
        }
    }


    //dump
    if (null != dumpHost) {
        int hash = Integer.parseInt(dumpHost);
        Container host = hostMap.get(hash);
        if (null != host) {
            dumpClass(host.getClass().toString().substring(6), request);
        }
    }
%>
<html>
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tomcat-Host列表</title>
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
            <h1>Tomcat-Host列表</h1>
        </div>
        <table class="table">
            <tr class="table-header">
                <th>类</th>
                <th>Name</th>
                <th>AppBase</th>
                <th>操作</th>
            </tr>
            <%
                hostChildren = engine.findChildren();
                for (Container hostChild : hostChildren) {

                    StandardHost host = (StandardHost)hostChild;

            %>
            <tr class="table-safe">
                <td style="text-align: left;font-family: 'consolas';"><%=host.getClass().toString().substring(6) %>
                </td>
                <td><%=host.getName() %>
                </td>
                <td><%=host.getAppBase() %>
                </td>
                </td>
                <td>
                    <button class="button" onclick="delHost('<%=hostChild.hashCode()%>')">delete</button>
                    <button class="button" onclick="dumpHost('<%=hostChild.hashCode()%>')">dump</button>
                </td>
            </tr>
            <%
                }
            %>
        </table>

        <form id="delHostForm" action="" method="get" style="display: none;">
            <input id="delHostHash" name="delHostHash">
        </form>
        <form id="dumpHostForm" action="" method="get" style="display: none;">
            <input id="dumpHostHash" name="dumpHostHash">
        </form>
    </div>
</div>
</body>
<script type="text/javascript">
function delHost(hostName){
	var msg = "确认删除吗?"
	if (confirm(msg)) {
		document.getElementById("delHostHash").value = hostName
		document.getElementById("delHostForm").submit()
	}
}
function dumpHost(hostName){
    var path = '<%=path%>'
    var msg = "dump出的文件存放在" + path + "目录中"
    alert(msg)
	document.getElementById("dumpHostHash").value = hostName
	document.getElementById("dumpHostForm").submit()
}
</script>
</html>
