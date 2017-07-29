if [[ -z $1 ]] ; then 
   echo "Usage: $0 jj.com"
   exit 1 
fi

output="$(nmap -sP 192.168.1.149/24 | grep -i node)"


echo '127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4' > /etc/hosts
echo '::1         localhost localhost.localdomain localhost6 localhost6.localdomain6' >> /etc/hosts

for i in $(seq 0 9) ; do
   regex="node00$i[[:blank:]]*\(([[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3})\)"
   if [[ "${output}" =~ $regex ]] ; then
      echo ${BASH_REMATCH[1]} node00${i} node00${i}.${1} >> /etc/hosts
   fi
done

