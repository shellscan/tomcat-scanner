<%@ page import="java.lang.reflect.Field" %>
<%@ page import="org.apache.catalina.core.*" %>
<%@ page import="java.io.File" %>
<%@ page import="com.sun.org.apache.bcel.internal.classfile.JavaClass" %>
<%@ page import="com.sun.org.apache.bcel.internal.Repository" %>
<%@ page import="java.io.FileOutputStream" %>
<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<%--
  Engine扫描
--%>
<%!
    class EngineBean{
        private String engineName;
        private String defaultHost;
        private String serviceName;
        private String webRoot;
        private String className;
        public String getDefaultHost() {
            return defaultHost;
        }
        public String getEngineName() {
            return engineName;
        }
        public String getServiceName() {
            return serviceName;
        }
        public String getWebRoot() {
            return webRoot;
        }
        public String getClassName() {
            return className;
        }
        public void setWebRoot(String webRoot) {
            this.webRoot = webRoot;
        }
        public void setDefaultHost(String engineClass) {
            this.defaultHost = engineClass;
        }
        public void setEngineName(String engineName) {
            this.engineName = engineName;
        }
        public void setServiceName(String serviceName) {
            this.serviceName = serviceName;
        }
        public void setClassName(String className) {
            this.className = className;
        }

        EngineBean(String engineName, String defaultHost, String serviceName, String webRoot, String className){
            this.engineName = engineName;
            this.defaultHost = defaultHost;
            this.serviceName = serviceName;
            this.webRoot = webRoot;
            this.className = className;
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
    //获得StandardEngine
    public StandardService getStandardService(StandardContext context){
        StandardEngine engine = (StandardEngine) context.getParent().getParent();
        return (StandardService) engine.getService();
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
    //dump class的位置
    String path = null;
%>
<%
    String dumpEngineName = request.getParameter("dumpEngineName");
    boolean runDump = dumpEngineName != null && !"".equals(dumpEngineName);
    path = getPath(request, "EngineScan.jsp").replaceAll("\\\\", "\\\\\\\\");
    if (runDump) {
        dumpClass(dumpEngineName);
    }

    StandardContext standardContext = getStandardContext(request);
    StandardService standardService = getStandardService(standardContext);
    StandardEngine standardEngine = (StandardEngine) standardService.getContainer();

    EngineBean engine = new EngineBean(standardEngine.getName(), standardEngine.getDefaultHost(),
            standardService.getName(), standardEngine.getCatalinaHome().getAbsolutePath(), standardService.getContainer().getClass().getName());
%>

<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tomcat-Engine列表</title>
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
<div class="content">
    <div class="">
        <div class="title">
            <h1>Tomcat-Engine列表</h1>
        </div>
        <table class="table">
            <tr class="table-header">
                <th>engine名</th>
                <th>所属service名</th>
                <th>默认host</th>
                <th>web根目录</th>
                <th>class名</th>
                <th>操作</th>
            </tr>
            <tr class="table-safe" >
                <div class="">
                    <td style="text-align: center;font-family: 'consolas';"><%=engine.getEngineName() %></td>
                    <td style="text-align: center;font-family: 'consolas';"><%=engine.getServiceName() %></td>
                    <td style="text-align: center;font-family: 'consolas';"><%=engine.getDefaultHost() %></td>
                    <td style="text-align: left;font-family: 'consolas';"><%=engine.getWebRoot()%></td>
                    <td style="text-align: left;font-family: 'consolas';"><%=engine.getClassName() %></td>
                </div>
                <td>
                    <button class="button" onclick="dumpValve('<%=engine.getClassName()%>')">dump</button>
                </td>
            </tr>
        </table>

        <form id="dumpEngine" action="" method="get" style="display: none;">
            <input id="dumpEngineName" name="dumpEngineName">
        </form>
    </div>
</div>
</body>
<script type="text/javascript">

    function dumpValve(engineName) {
        var msg = "dump出的文件存放在<%=path%>目录中"
        alert(msg)
        document.getElementById("dumpEngineName").value = engineName
        document.getElementById("dumpEngine").submit()
    }
</script>
</html>