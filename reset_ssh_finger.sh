#!/bin/bash

NODO1=192.168.122.101
NODO2=192.168.122.102
NODO3=192.168.122.103

ssh-keygen -f '/home/vicenterog/.ssh/known_hosts' -R $NODO1
ssh-keygen -f '/home/vicenterog/.ssh/known_hosts' -R $NODO2
ssh-keygen -f '/home/vicenterog/.ssh/known_hosts' -R $NODO3

ssh -o StrictHostKeyChecking=no $NODO1 'echo Reset SSH NODO1 exitoso'
ssh -o StrictHostKeyChecking=no $NODO2 'echo Reset SSH NODO2 exitoso'
ssh -o StrictHostKeyChecking=no $NODO3 'echo Reset SSH NODO3 exitoso'
