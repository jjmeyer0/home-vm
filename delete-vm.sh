if [ -z $1 ]; then echo 'Must specify a vm to delete' ; exit 1; fi
echo "Deleting vm: $1" 
virsh destroy $1 || true
virsh undefine $1 || true
rm -rf /home/data/vm/images/$1.qcow2 || true
