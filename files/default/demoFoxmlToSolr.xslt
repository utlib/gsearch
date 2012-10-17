<?xml version="1.0" encoding="UTF-8"?> 
<!-- $Id: demoFoxmlToLucene.xslt 5734 2006-11-28 11:20:15Z gertsp $ -->
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"   
    	xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
    	exclude-result-prefixes="exts"
	xmlns:zs="http://www.loc.gov/zing/srw/"
	xmlns:foxml="info:fedora/fedora-system:def/foxml#"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
	xmlns:uvalibdesc="http://dl.lib.virginia.edu/bin/dtd/descmeta/descmeta.dtd"
	xmlns:uvalibadmin="http://dl.lib.virginia.edu/bin/admin/admin.dtd/"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
	xmlns:rel="info:fedora/fedora-system:def/relations-external#"
	xmlns:mods="http://www.loc.gov/mods/v3"
	xmlns:islandora-exts="xalan://ca.upei.roblib.DataStreamForXSLT"
	xmlns:fedora-model="info:fedora/fedora-system:def/model#"
	xmlns:fedora="info:fedora/fedora-system:def/relations-external#">
	
	<xsl:output method="xml" indent="yes" encoding="UTF-8"/>

<!--
	 This xslt stylesheet generates the Solr doc element consisting of field elements
     from a FOXML record. The PID field is mandatory.
     Options for tailoring:
       - generation of fields from other XML metadata streams than DC
       - generation of fields from other datastream types than XML
         - from datastream by ID, text fetched, if mimetype can be handled
             currently the mimetypes text/plain, text/xml, text/html, application/pdf can be handled.
-->

	<xsl:param name="REPOSITORYNAME" select="repositoryName"/>
	<xsl:param name="FEDORASOAP" select="repositoryName"/>
	<xsl:param name="FEDORAUSER" select="repositoryName"/>
	<xsl:param name="FEDORAPASS" select="repositoryName"/>
	<xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
	<xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>
	<xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>
	<xsl:variable name="docBoost" select="1.4*2.5"/> <!-- or any other calculation, default boost is 1.0 -->
	
	<xsl:template match="/">
		<add> 
		<doc> 
			<xsl:attribute name="boost">
				<xsl:value-of select="$docBoost"/>
			</xsl:attribute>
		<!-- The following allows only active demo FedoraObjects to be indexed. -->
		<xsl:if test="foxml:digitalObject/foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state' and @VALUE='Active']">
			<xsl:if test="not(foxml:digitalObject/foxml:datastream[@ID='METHODMAP'] or foxml:digitalObject/foxml:datastream[@ID='DS-COMPOSITE-MODEL'])">
				<xsl:apply-templates mode="activeDemoFedoraObject"/>
			</xsl:if>
		</xsl:if>
		</doc>
		</add>
	</xsl:template>

	<xsl:template match="/foxml:digitalObject" mode="activeDemoFedoraObject">
		<field name="PID" boost="2.5">
			<xsl:value-of select="$PID"/>
		</field>
		<xsl:for-each select="foxml:objectProperties/foxml:property">
			<field >
				<xsl:attribute name="name"> 
					<xsl:value-of select="concat('fgs.', substring-after(@NAME,'#'))"/>
				</xsl:attribute>
				<xsl:value-of select="@VALUE"/>
			</field>
		</xsl:for-each>
		<xsl:for-each select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/oai_dc:dc/*">
			<field >
				<xsl:attribute name="name">
					<xsl:value-of select="concat('dc.', substring-after(name(),':'))"/>
				</xsl:attribute>
				<xsl:value-of select="text()"/>
			</field>
		</xsl:for-each>

		<!-- a managed datastream is fetched, if its mimetype 
		     can be handled, the text becomes the value of the field. -->
		<xsl:for-each select="foxml:datastream[@CONTROL_GROUP='M']">
			<field index="TOKENIZED" store="YES" termVector="NO">
				<xsl:attribute name="name">
					<xsl:value-of select="concat('dsm.', @ID)"/>
				</xsl:attribute>
				<xsl:value-of select="exts:getDatastreamText($PID, $REPOSITORYNAME, @ID, $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
			</field>
		</xsl:for-each>
                <!-- Add the following lines to index the RELS-EXT Datastream:-->
		<xsl:for-each select="foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion[last()]/foxml:xmlContent//rdf:Description/*">
	                <field>
		                <xsl:attribute name="name">
					<xsl:value-of select="concat('rels.', local-name())"/>
				</xsl:attribute>
				<xsl:choose>
					<xsl:when test="@rdf:resource"><!-- Deal with URIs/resources -->
					        <xsl:value-of select="@rdf:resource"/>
				        </xsl:when>
				        <xsl:otherwise><!-- otherwise, assume it's a literal -->
						<xsl:value-of select="text()"/>
					</xsl:otherwise>
				</xsl:choose>
			</field>
                </xsl:for-each>
                <!-- Added the above-->

<!-- get the mods of the parent book if this object is a pageCmodel object-->
 
		<xsl:variable name="thisCurrentCModel">
			<xsl:value-of select="foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion[last()]/foxml:xmlContent//rdf:Description/fedora-model:hasModel/@rdf:resource"/>
		</xsl:variable>
		<xsl:if test="$thisCurrentCModel = 'info:fedora/islandora:pageCModel'">
			<!-- get the parent pid-->
		        <xsl:variable name="Book_Pid">
				<xsl:value-of select="foxml:datastream[@ID='RELS-EXT']/foxml:datastreamVersion[last()]/foxml:xmlContent//rdf:Description/rel:isMemberOf/@rdf:resource"/>
			</xsl:variable>
		        <field>
				<xsl:attribute name="name">PARENT_pid</xsl:attribute>
				<xsl:value-of select="substring($Book_Pid,13)"/>
		        </field>
			<xsl:variable name="PARENT_MODS"
			    select="islandora-exts:getXMLDatastreamASNodeList(substring($Book_Pid,13), $REPOSITORYNAME, 'MODS', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>

		        <!--<xsl:variable name="PARENT_MODS" select="document(concat($PROT, '://', $LOCALFEDORAUSERNAME, ':', $LOCALFEDORAPASSWORD, '@',
		            $HOST, ':', $PORT, '/fedora/objects/', substring($Book_Pid,13), '/datastreams/', 'MODS', '/content'))"/>-->
		        <xsl:for-each select="$PARENT_MODS//mods:title">
		            <field>
		                <xsl:attribute name="name">
		                    <xsl:value-of select="concat('PARENT_', local-name())"/>
		                </xsl:attribute>
		                <xsl:value-of select="normalize-space(text())"/>
		            </field>
		        </xsl:for-each>
		        <xsl:for-each select="$PARENT_MODS//mods:originInfo/mods:dateIssued">
		            <field>
		                <xsl:attribute name="name">
		                    <xsl:value-of select="concat('PARENT_', local-name())"/>
		                </xsl:attribute>
		                <xsl:value-of select="normalize-space(text())"/>
		            </field>
		        </xsl:for-each>
		        <xsl:for-each select="$PARENT_MODS//mods:genre">
		            <field>
		                <xsl:attribute name="name">
		                    <xsl:value-of select="concat('PARENT_', local-name())"/>
		                </xsl:attribute>
		                <xsl:value-of select="normalize-space(text())"/>
		            </field>
		        </xsl:for-each>
		        <xsl:for-each select="$PARENT_MODS//mods:subject/mods:name/mods:namePart/*">
		            <xsl:if test="text() [normalize-space(.) ]">
		                <!--don't bother with empty space-->
		                <field>
		                    <xsl:attribute name="name">
		                        <xsl:value-of select="concat('PARENT_', 'subject')"/>
		                    </xsl:attribute>
		                    <xsl:value-of select="normalize-space(text())"/>
		                </field>
		            </xsl:if>
		        </xsl:for-each>
		        <xsl:for-each select="$PARENT_MODS//mods:topic">
		            <xsl:if test="text() [normalize-space(.) ]">
		                <!--don't bother with empty space-->
		                <field>
		                    <xsl:attribute name="name">
		                        <xsl:value-of select="concat('PARENT_', 'topic')"/>
		                    </xsl:attribute>
		                    <xsl:value-of select="normalize-space(text())"/>
		                </field>
		            </xsl:if>
		        </xsl:for-each> 
		        <xsl:for-each select="$PARENT_MODS//mods:geographic">
			<xsl:if test="text() [normalize-space(.) ]">
			    <!--don't bother with empty space-->
			    <field>
			        <xsl:attribute name="name">
			            <xsl:value-of select="concat('PARENT_', 'geographic')"/>
			        </xsl:attribute>
			        <xsl:value-of select="normalize-space(text())"/>
			    </field>
			</xsl:if>
			</xsl:for-each>
			<xsl:for-each select="$PARENT_MODS//mods:subject/mods:name/mods:namePart/*">
			    <xsl:if test="text() [normalize-space(.) ]">
			        <!--don't bother with empty space-->
			        <field>
			            <xsl:attribute name="name">
			                <xsl:value-of select="concat('PARENT_', 'subject')"/>
			            </xsl:attribute>
			            <xsl:value-of select="normalize-space(text())"/>
			        </field>
			    </xsl:if>
			</xsl:for-each>
			<xsl:for-each select="$PARENT_MODS//mods:part/mods:detail/*">
			    <xsl:variable name="TYPE">
			        <xsl:value-of select="../@type"/>
			    </xsl:variable>
			    <field>
			        <xsl:attribute name="name">
			            <xsl:value-of select="concat('PARENT_', $TYPE)"/>
			        </xsl:attribute>
			        <xsl:value-of select="."/>
			    </field>
			</xsl:for-each>
		</xsl:if>
	        <!--************************END PAGE PARENT MODS ***********************************************************-->			
	</xsl:template>
</xsl:stylesheet>	
