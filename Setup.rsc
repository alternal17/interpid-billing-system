# Set System Identity
/system identity set name=ULTRA.NET

# Create ULTRA Bridge
/interface bridge
add name="ULTRA Main bridge"

# Rename ether4 to "Internet Source"
/interface ethernet
set [ find default-name=ether4 ] name="Internet Source"

# Create a Hotspot Profile
/ip hotspot profile
add hotspot-address=30.0.0.1 login-by=cookie,http-chap,http-pap,mac-cookie \
    name="ULTRA Hotspot Profile" radius-interim-update=10m use-radius=yes

# Create Pool for Hotspot
/ip pool
add name="ULTRA Hotspot Pool" ranges=30.0.0.2-30.0.0.254

# Create a dhcp server for hotspot pool
/ip dhcp-server
add address-pool="ULTRA Hotspot Pool" disabled=no interface=\
    "ULTRA Main bridge" lease-time=1h name="ULTRA Dhcp Server"

# Create NOVANET Hotspot Server
/ip hotspot
add address-pool="ULTRA Hotspot Pool" addresses-per-mac=1 disabled=no \
    interface="ULTRA Main bridge" name="ULTRA Hotspot" profile=\
    "ULTRA Hotspot Profile"

# Hotspot Network IP Address
/ip address
add address=30.0.0.1/24 comment="hotspot network" interface=\
    "ULTRA Main bridge" network=30.0.0.0
/ip dhcp-server network
add address=30.0.0.0/24 comment="hotspot network" gateway=30.0.0.1

# Firewall rules for ICMP and Client Isolation
/ip firewall filter
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
add action=drop chain=input comment="ICMP Block on ULTRA Bridge" \
    in-interface="ULTRA Main bridge" protocol=icmp
add action=drop chain=forward comment="Client Isolation for Hotspot" \
    dst-address=30.0.0.0/24 in-interface="ULTRA Main bridge" src-address=\
    30.0.0.0/24

# Mangle rules for Anti-sharing and Hide Router IP
/ip firewall mangle
add action=change-ttl chain=postrouting comment=\
    "ULTRA Hotspot Anti-sharing" new-ttl=set:1 out-interface=\
    "ULTRA Main bridge" passthrough=yes
add action=change-ttl chain=prerouting comment="Router Hide IP" new-ttl=\
    increment:2 passthrough=yes

# NAT rule for Hotspot
/ip firewall nat
add action=passthrough chain=unused-hs-chain comment=\
    "place hotspot rules here" disabled=yes
add action=masquerade chain=srcnat comment=\
    "ULTRA masquerade hotspot network" src-address=30.0.0.0/24
add action=masquerade chain=srcnat comment=\
    "Masquerade WAN" out-interface="Internet Source"

# Set time to Nairobi Kenya
/system clock
set time-zone-autodetect=no time-zone-name=Africa/Nairobi



# Add ports to ULTRA Main bridge
/interface bridge port
add bridge="ULTRA Main bridge" interface=ether2
add bridge="ULTRA Main bridge" interface=ether3
add bridge="ULTRA Main bridge" interface=wlan1


# 1. Add Paystack to Walled Garden so they can pay before login
/ip hotspot walled-garden
add dst-host=*.paystack.com
add dst-host=*.paystack.co
add dst-host=*.pstk.xyz
add dst-host=checkout.paystack.com


#Create hospot user profile, edit based on your needs
/ip hotspot user profile
add name="3m" session-timeout=3m
add name="test" session-timeout=3m
add name="5hr" session-timeout=05:00:00
add name="12hr" session-timeout=12:00:00
add name="1day" session-timeout=24:00:00

#Create hotspot users-----------

{
:local chars "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
:local charLen [:len $chars];

# Profiles list
:local profiles {"test"; "5hr"; "12hr"; "1day"};

:foreach p in=$profiles do={
    :for i from=1 to=25 do={
        :local user "";
        :local pass "";
        
        # Generate 8-character random username
        :for j from=1 to=8 do={
            :set user ($user . [:pick $chars [:rndnum from=0 to=($charLen - 1)]]);
        }
        
        # Generate 8-character random password
        :for j from=1 to=8 do={
            :set pass ($pass . [:pick $chars [:rndnum from=0 to=($charLen - 1)]]);
        }
        
        /ip hotspot user add name=$user password=$pass profile=$p comment=("Auto-" . $p);
        :put ("Created: " . $user . " | Pass: " . $pass . " | Profile: " . $p);
    }
}
}


#Disable radius server-------------------
/ip hotspot profile
set [find name="ULTRA Hotspot Profile"] use-radius=no radius-accounting=no login-by=cookie,http-chap,http-pap,trial


#....Access winbox from the web.....
/ip service enable www
/ip service set www address=0.0.0.0/0
/ip address add address=1.2.3.4/24 interface="ULTRA Main bridge" comment="Local API IP"
/ip hotspot walled-garden ip
add dst-address=1.2.3.4 comment="API access before login"
/ip firewall filter
add chain=input action=accept in-interface="ULTRA Main bridge" dst-address=1.2.3.4 protocol=tcp dst-port=80,443 comment="Allow webfig access from hotspot LAN"
/ip dns static
add name=ULTRA.webfig.com address=1.2.3.4

# --- Use this to get your User Pool list for JavaScript ---
{
    :put "Generating User Pool for GitHub/JS..."
    :foreach i in=[/ip hotspot user find where comment~"Auto-"] do={
        :local uname [/ip hotspot user get $i name];
        :local upass [/ip hotspot user get $i password];
        :local uprof [/ip hotspot user get $i profile];
        
        # This prints exactly: {u: "username", p: "password"},
        :put ("$uprof pool: {u: \"$uname\", p: \"$upass\"},");
    }
}

