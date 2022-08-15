<%@page import="org.apache.catalina.Container"%>
<%@page import="java.util.List"%>
<%@page import="java.util.ArrayList"%>
<%@page import="org.apache.catalina.Valve"%>
<%@page import="javax.management.ObjectName"%>
<%@page import="java.lang.reflect.Field"%>
<%@page import="org.apache.catalina.connector.Request"%>
<%@ page import="java.io.File" %>
<%@ page import="java.io.FileOutputStream" %>
<%@ page import="com.sun.org.apache.bcel.internal.classfile.JavaClass" %>
<%@ page import="com.sun.org.apache.bcel.internal.Repository" %>
<%@ page import="org.apache.catalina.core.*" %>
<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%--
  Tomcat中Valve扫描,从engine、host、context和wrapper中获取
--%>
<%!
//自定义valvebean
class ValveBean {
	private String valveName;
	private String container;
	private int hashCode;
	private String details;
	private String parent;
	public String getValveName() {
		return valveName;
	}
	public void setValveName(String valveName) {
		this.valveName = valveName;
	}
	public String getContainer() {
		return container;
	}
	public void setContainer(String container) {
		this.container = container;
	}
	public int getHashCode() {
		return hashCode;
	}
	public void setHashCode(int hashCode) {
		this.hashCode = hashCode;
	}
	public String getDetails() {
		return details;
	}
	public void setDetails(String details) {
		this.details = details;
	}
	public String getParent() {
		return parent;
	}
	public void setParent(String parent) {
		this.parent = parent;
	}
}
//获取Request
public Request getRequest(HttpServletRequest request) throws Exception{
	Field field1 = request.getClass().getDeclaredField("request");
	field1.setAccessible(true);
	return (Request)field1.get(request);
}
//获得pipeline
public Field getPipeline() throws Exception{
	Field field3 = ContainerBase.class.getDeclaredField("pipeline");
	field3.setAccessible(true);
	return field3;
}

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
//获取engine
public StandardEngine getEngine(StandardContext context){
	return (StandardEngine)context.getParent().getParent();
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
//dumpclass的位置
String path = null;
%>
<%
	String delValveName = request.getParameter("delValveName");
	String hashcode = request.getParameter("hashcode");
	String container = request.getParameter("container");

	String dumpValveName = request.getParameter("dumpValveName");
	boolean runDel = delValveName != null && !"".equals(delValveName);
	boolean runDump = dumpValveName != null && !"".equals(dumpValveName);
	path = getPath(request, "ValveScan.jsp").replaceAll("\\\\", "\\\\\\\\");

	if (runDump) {
		dumpClass(dumpValveName);
	}

	//保存结果
	List<ValveBean> results = new ArrayList<>();

	//获得StandardContext
	StandardContext tmpContext = getStandardContext(request);
	//获得Engine
	StandardEngine engine = getEngine(tmpContext);
	//获取engine相关的valve
	StandardPipeline enginePipeline = (StandardPipeline) engine.getPipeline();
	ObjectName[] engineObjectName = enginePipeline.getValveObjectNames();
	Valve[] engineValve = enginePipeline.getValves();
	for (int index = 0; index < engineObjectName.length; index++) {
		//判断是否执行删除
		if (runDel && "StandardEngine".equals(container) && engineValve[index].getClass().getName().equals(delValveName)
				&& engineValve[index].hashCode() == Integer.parseInt(hashcode)) {
			enginePipeline.removeValve(engineValve[index]);
			continue;
		}
		ValveBean valveBean = new ValveBean();
		valveBean.setContainer("StandardEngine");
		valveBean.setValveName(engineValve[index].getClass().getName());
		valveBean.setHashCode(engineValve[index].hashCode());
		valveBean.setDetails(engine.getName());
		results.add(valveBean);
	}
	//获得所有host
	Container[] hostChildren = engine.findChildren();
	for (Container hostChild : hostChildren) {
		StandardHost host = (StandardHost)hostChild;
		StandardPipeline hostPipeline = (StandardPipeline) host.getPipeline();
		ObjectName[] hostObjectName = hostPipeline.getValveObjectNames();
		Valve[] hostValve = hostPipeline.getValves();
		for (int index = 0; index < hostObjectName.length; index++) {
			//判断是否执行删除
			if (runDel && "StandardHost".equals(container) && hostValve[index].getClass().getName().equals(delValveName)
					&& hostValve[index].hashCode() == Integer.parseInt(hashcode)) {
				hostPipeline.removeValve(hostValve[index]);
				continue;
			}
			ValveBean valveBean = new ValveBean();
			valveBean.setContainer("StandardHost");
			valveBean.setValveName(hostValve[index].getClass().getName());
			valveBean.setHashCode(hostValve[index].hashCode());
			valveBean.setDetails(host.getName());
			valveBean.setParent(engine.getName());
			results.add(valveBean);
		}
		//获得所有context
		Container[] contextChildren = host.findChildren();
		for (Container contextChild : contextChildren) {
			StandardContext context = (StandardContext)contextChild;
			StandardPipeline contextPipeline = (StandardPipeline)context.getPipeline();
			ObjectName[] contextObjectName = contextPipeline.getValveObjectNames();
			Valve[] contextValve = contextPipeline.getValves();
			for (int index = 0; index < contextObjectName.length; index++) {
				//判断是否执行删除
				if (runDel && "StandardContext".equals(container) && contextValve[index].getClass().getName().equals(delValveName)
						&& contextValve[index].hashCode() == Integer.parseInt(hashcode)) {
					contextPipeline.removeValve(contextValve[index]);
					continue;
				}
				ValveBean valveBean = new ValveBean();
				valveBean.setContainer("StandardContext");
				valveBean.setValveName(contextValve[index].getClass().getName());
				valveBean.setHashCode(contextValve[index].hashCode());
				valveBean.setDetails(context.getName() == null || "".equals(context.getName()) ? "ecology" : context.getName());
				valveBean.setParent(host.getName());
				results.add(valveBean);
			}
			//获得所有wrapper
			Container[] wrapperChildren = context.findChildren();
			for (Container wrapperChild : wrapperChildren) {
				StandardWrapper wrapper = (StandardWrapper)wrapperChild;
				StandardPipeline wrapperPipeline = (StandardPipeline) wrapper.getPipeline();
				ObjectName[] wrapperObjectName = wrapperPipeline.getValveObjectNames();
				Valve[] wrapperValve = wrapperPipeline.getValves();
				for (int index = 0; index < wrapperObjectName.length; index++) {
					//判断是否执行删除
					if (runDel && "StandardWrapper".equals(container) && wrapperValve[index].getClass().getName().equals(delValveName)
							&& wrapperValve[index].hashCode() == Integer.parseInt(hashcode)) {
						wrapperPipeline.removeValve(wrapperValve[index]);
						continue;
					}
//					wrapperValve[index].
					ValveBean valveBean = new ValveBean();
					valveBean.setContainer("StandardWrapper");
					valveBean.setValveName(wrapperValve[index].getClass().getName());
					valveBean.setHashCode(wrapperValve[index].hashCode());
					valveBean.setDetails(wrapper.getName());
					valveBean.setParent(context.getName() == null || "".equals(context.getName()) ? "ecology" : context.getName());
					results.add(valveBean);
				}
			}
		}
	}
%>

<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tomcat-Valve列表</title>
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
            <h1>Tomcat-Valve列表</h1>
        </div>
        <table class="table">
            <tr class="table-header">
                <th>Valve名</th>
                <th>所属容器类型</th>
				<th>所属容器名/对应的servlet</th>
				<th>所属上级容器名</th>
                <th>hash</th>
                <th>操作</th>
            </tr>
            <%
                for (int index = 0;index < results.size();index ++) {
                	ValveBean valve = results.get(index);
            %>
            <tr class="table-safe" >
				<div class="">
					<td style="text-align: left;font-family: 'consolas';"><%=valve.getValveName() %></td>
					<td style="text-align: center;font-family: 'consolas';"><%=valve.getContainer() %></td>
					<td style="text-align: center;font-family: 'consolas';"><%=valve.getDetails() %></td>
					<td style="text-align: center;font-family: 'consolas';"><%=valve.getParent() == null ? "无" : valve.getParent()%></td>
					<td style="text-align: center;font-family: 'consolas';"><%=valve.getHashCode() %></td>
				</div>
                <td>
                	<button class="button" onclick="delValve('<%=valve.getValveName()%>','<%=valve.getContainer()%>','<%=valve.getHashCode()%>')">delete</button>
                    <button class="button" onclick="dumpValve('<%=valve.getValveName()%>')">dump</button>
                </td>
            </tr>
            <%
                }
            %>
        </table>

        <form id="delValveForm" action="" method="get" style="display: none;">
            <input id="delValveName" name="delValveName">
            <input id="container" name="container">
            <input id="hashcode" name="hashcode">
            <input id="dumpValveName" name="dumpValveName">
        </form>
    </div>
</div>
</body>
<script type="text/javascript">
function delValve(valveName,container,hashcode){
	var msg = "确认删除" + container + "容器中的" + valveName + "吗?"
	if (confirm(msg)) {
		document.getElementById("delValveName").value = valveName
		document.getElementById("container").value = container
		document.getElementById("hashcode").value = hashcode
		document.getElementById("dumpValveName").value = null
		document.getElementById("delValveForm").submit()
	}
}

function dumpValve(valveName) {
	var msg = "dump出的文件存放在<%=path%>目录中"
	alert(msg)
	document.getElementById("delValveName").value = null
	document.getElementById("container").value = null
	document.getElementById("hashcode").value = null
	document.getElementById("dumpValveName").value = valveName
	document.getElementById("delValveForm").submit()
}
</script>
</html>