<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:outline="http://wkhtmltopdf.org/outline"
                xmlns="http://www.w3.org/1999/xhtml">
  <xsl:output doctype-public="-//W3C//DTD XHTML 1.0 Strict//EN"
              doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"
              indent="yes" />

  <!-- Максимальная глубина TOC (1 = только H1, 2 = H1 и H2) -->
  <xsl:param name="max-depth" select="2"/>

  <xsl:template match="outline:outline">
    <html>
      <head>
        <title>Оглавление</title>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
        <style>
          body {
            font-family: 'DejaVu Sans', Arial, sans-serif;
            font-size: 14pt;
            padding: 20px 40px;
          }
          h1 {
            text-align: center;
            font-size: 24pt;
            font-weight: bold;
            margin-bottom: 30px;
            border-bottom: 2px solid #333;
            padding-bottom: 10px;
          }
          ul {
            list-style: none;
            padding-left: 0;
            margin: 0;
          }
          ul ul {
            padding-left: 25px;
          }
          li {
            margin: 8px 0;
          }
          div {
            border-bottom: 1px dotted #ccc;
            padding-bottom: 3px;
            overflow: hidden;
          }
          a {
            text-decoration: none;
            color: #333;
          }
          span {
            float: right;
            color: #666;
            padding-left: 10px;
          }
          /* Уровень 1 - жирный */
          .level-1 a {
            font-weight: bold;
            font-size: 14pt;
          }
          /* Уровень 2 - обычный */
          .level-2 a {
            font-size: 13pt;
          }
        </style>
      </head>
      <body>
        <h1>Оглавление</h1>
        <ul>
          <xsl:apply-templates select="outline:item/outline:item">
            <xsl:with-param name="depth" select="1"/>
          </xsl:apply-templates>
        </ul>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="outline:item">
    <xsl:param name="depth" select="1"/>

    <!-- Показываем только если глубина <= max-depth -->
    <xsl:if test="$depth &lt;= $max-depth">
      <li>
        <xsl:attribute name="class">level-<xsl:value-of select="$depth"/></xsl:attribute>
        <xsl:if test="@title!=''">
          <div>
            <a>
              <xsl:if test="@link">
                <xsl:attribute name="href"><xsl:value-of select="@link"/></xsl:attribute>
              </xsl:if>
              <xsl:if test="@backLink">
                <xsl:attribute name="name"><xsl:value-of select="@backLink"/></xsl:attribute>
              </xsl:if>
              <xsl:value-of select="@title" />
            </a>
            <span><xsl:value-of select="@page" /></span>
          </div>
        </xsl:if>
        <xsl:if test="$depth &lt; $max-depth and outline:item">
          <ul>
            <xsl:apply-templates select="outline:item">
              <xsl:with-param name="depth" select="$depth + 1"/>
            </xsl:apply-templates>
          </ul>
        </xsl:if>
      </li>
    </xsl:if>
  </xsl:template>
</xsl:stylesheet>
