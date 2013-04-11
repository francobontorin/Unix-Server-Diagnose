UNIX Server Diagnose
-

An audit defines a set of rules or configuration values you use to determine if the configuration of a server or group of servers match your organization’s desired compliance standards.
The UNIX Server Diagnose Script can compare a server’s configuration against the rules defined by the company, check that a configuration value meets the criteria specified in the template, or simply check to ensure that a specific value does or does not exist.

<b>Features<b/>

The key function of this Tool is enabling the ability to generate a Server Diagnose and Compliance Report on all supported Unix/Linux platforms (AIX, Solaris SPARC and RHEL) in a fully automated way.
It is displayed in the end of the script execution a detailed output showing the points that do not match the defined versions/standards, and/or the points missing for the box to become compliant.
 * Modular and function based script developed in Shell/Perl Script
 * Korn Shell Compliance (AIX/Linux/Solaris)
 * Flexible and Easy to support
 * It covers Hardware, Network, File Systems and Software’s verification

<b>Author<b/>

  * Franco Bontorin (francobontorin at gmail.com)
  * Senior Unix Architect

<b>License<b/>
  * This is under GNU GPL v2

<b>Limitations<b/>

  * Here are only the scripts to build the Diagnostic/Compliance script, a template with the default values must be created
  * This is an example how the template could be created
 
$ cat Compliance.tplt

# OPERATING SYSTEM TEMPLATE
AIX7-KERNEL     7100-02-01-1245
SUNOS-KERNEL    147440-27
RHEL5-KERNEL    2.6.18-348.el5
RHEL6-KERNEL    2.6.32-279.19.1.el6.x86_64
 
# SOFTWARE TEMPLATE
AIX-POWERPATH   5.5P05(build1)
AIX-ODM         5.3.0.6
SUNOS-POWERPATH 5.5.P01_b002
 
# NETWORK TEMPLATE
192.168.32.130  255.255.255.0   192.168.32.2

<b>Date<b/>

  * March 2013
