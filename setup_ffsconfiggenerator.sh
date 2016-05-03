setup_ffsconfiggenerator_config() {
if [ ! -d FfsConfigGenerator ]; then
  pip2 install --upgrade netaddr
  git clone https://github.com/freifunk-stuttgart/FfsConfigGenerator.git
  cd FfsConfigGenerator
else
  cd FfsConfigGenerator
  git checkout -- config.json
  git pull
fi
python -c '
import json, sys
GWID='$GWID'
fp = open("config.json","rb")
config = json.load(fp)
fp.close()
if ( "$GWID" not in config["gws"] ):
  fp = open("config.json","wb")
  config["gws"][GWID] = {}
  config["gws"][GWID]["legacyipv4"] = "'$LEGIP'"
  config["gws"][GWID]["legacyipv6"] = "fd21:b4dc:4b1e::a38:'$GWLID'"
  config["gws"][GWID]["externalipv4"] = "'$EXT_IP_V4'"
  config["gws"][GWID]["externalipv6"] = "'$EXT_IPS_V6'"
  config["gws"][GWID]["ipv4start"] = "172.21.'$((4*$GWID))'.2"
  config["gws"][GWID]["ipv4end"] = "172.21.'$((4*$((GWID+1))-1))'.254"
  json.dump(config, fp, indent=2)
  fp.close()
'
}
