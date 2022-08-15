<%@ page import="java.lang.reflect.Field" %>
<%@ page import="org.apache.catalina.Service" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.List" %>
<%@ page import="java.io.File" %>
<%@ page import="com.sun.org.apache.bcel.internal.classfile.JavaClass" %>
<%@ page import="com.sun.org.apache.bcel.internal.Repository" %>
<%@ page import="java.io.FileOutputStream" %>
<%@ page import="org.apache.catalina.core.*" %>
<%--
  Service扫描
--%>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%!
    class ServiceBean{
        private String serviceName;
        private String serviceClass;

        ServiceBean(String serviceName, String serviceClass){
            this.serviceName = serviceName;
            this.serviceClass = serviceClass;
        }

        public void setServiceName(String serviceName) {
            this.serviceName = serviceName;
        }
        public void setServiceClass(String serviceClass) {
            this.serviceClass = serviceClass;
        }
        public String getServiceName() {
            return serviceName;
        }
        public String getServiceClass() {
            return serviceClass;
        }
    }
    //获得StandardContext
    public StandardContext getStandardContext(HttpServletRequest request) throws Exception{
        ServletContext servletContext = request.getSession().getServletContext();
        Field appctx = servletContext.getClass().getDeclaredField("context");
        appctx.setAccessible(true);
        ApplicationContext applicationContext = (ApplicationContext) appctx.get(servletContext);
        //获取StandardContext
        Field context = applicationContext.getClass().getDeclaredField("context");
        context.setAccessible(true);
        return (StandardContext) context.get(applicationContext);
    }
    //获得StandardContext
    public Service[] getStandardService(StandardContext context) throws Exception{
        StandardEngine engine = (StandardEngine)context.getParent().getParent();
        StandardService service = (StandardService)engine.getService();
        server = (StandardServer)service.getServer();
        return server.findServices();
    }
    //获取当前路径
    public String getPath(HttpServletRequest req,String filename) {
        String path = req.getSession().getServletContext().getRealPath(filename);
        return path.substring(0, path.lastIndexOf(File.separator));
    }
    //dump class
    public void dumpClass(String className) {
        try {
            JavaClass javaClass = Repository.lookupClass(Class.forName(className));
            String simpleClassName = className.substring(className.lastIndexOf(".") + 1);
            FileOutputStream fos = new FileOutputStream(path + File.separator + simpleClassName + ".dump");
            javaClass.dump(fos);
        } catch (Exception e) {
        }
    }
    public void deleteService(String deleteServiceName){
        for (Service service : server.findServices()) {
            if (service.getName().equals(deleteServiceName)) {
                server.removeService(service);
            }
        }
    }
    StandardServer server = null;
    String path = "";
%>
<%
    String dumpServiceName = request.getParameter("dumpServiceName");
    String deleteServiceName = request.getParameter("deleteServiceName");
    boolean runDump = dumpServiceName != null && !"".equals(dumpServiceName);
    boolean runDel = deleteServiceName != null && !"".equals(deleteServiceName);
    path = getPath(request, "ServiceScan.jsp").replaceAll("\\\\", "\\\\\\\\");
    if (runDump) {
        dumpClass(dumpServiceName);
    }
    if (runDel) {
        deleteService(deleteServiceName);
    }

    StandardContext standardContext = getStandardContext(request);
    Service[] services = getStandardService(standardContext);
    List<ServiceBean> result = new ArrayList<>();
    for (Service service:services) {
        StandardService standardService = (StandardService)service;
        ServiceBean serviceBean = new ServiceBean(standardService.getName(),standardService.getClass().getName());
        result.add(serviceBean);
    }
%>

<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tomcat-Service列表</title>
    <style>
        .body {
            width: 100%;
            margin: 0 auto;
            font-family: "consolas";
            background-color: #DCDCDC;
        }
        .content{
            width: 100%;
            margin-top: 50px;
        }
        .title {
            text-align: center;
        }
        .table {
            width: 80%;
            margin:0 auto;
            border-radius: 4px;
            padding: 5px;
        }
        .table-header{
            text-align: center;
        }
        .table-header th{
            border:2px solid #000000;
            border-radius: 1px;
        }
        .table-safe td{
            border:2px solid #000000;
            border-radius: 1px;
        }
        .table-safe{
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
            <h1>Tomcat-Service列表</h1>
        </div>
        <table class="table">
            <tr class="table-header">
                <th>service名</th>
                <th>service类</th>
                <th>操作</th>
            </tr>
            <%
                for(int index = 0;index < result.size();index ++) {
                    ServiceBean service = result.get(index);
            %>
            <tr class="table-safe" >
                <td style="text-align: center;font-family: 'consolas';"><%=service.getServiceName() %></td>
                <td style="text-align: center;font-family: 'consolas';"><%=service.getServiceClass() %></td>
                <td>
                    <button class="button" onclick="deleteService('<%=service.getServiceName()%>')">delete</button>
                    <button class="button" onclick="dumpService('<%=service.getServiceClass()%>')">dump</button>

                </td>
            </tr>
            <%
                }
            %>
        </table>

        <form id="dumpService" action="" method="get" style="display: none;">
            <input id="dumpServiceName" name="dumpServiceName">
            <input id="deleteServiceName" name="deleteServiceName">
        </form>
    </div>
</div>
</body>
<script type="text/javascript">

    function deleteService(name){
        var msg = "确认删除" + name + "吗?"
        alert(msg)
        document.getElementById("dumpServiceName").value = null
        document.getElementById("deleteServiceName").value = name
        document.getElementById("dumpService").submit()
    }
    function dumpService(serviceName) {
        var msg = "dump出的文件存放在<%=path%>目录中"
        alert(msg)
        document.getElementById("dumpServiceName").value = serviceName
        document.getElementById("dumpService").submit()
    }
</script>
</html>