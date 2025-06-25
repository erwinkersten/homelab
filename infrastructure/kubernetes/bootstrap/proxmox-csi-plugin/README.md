# Proxmox CSI Plugin Configuration

The Proxmox environment is bootstrapped for the Proxmox CSI plugin. The Proxmox CSI Plugin requires the correct privileges to allocate and attach disks.

The following configuration is applied:

1. **Proxmox CSI Role**: A Proxmox role named `CSI` is created with the following privileges:
   - `Datastore.Audit`
   - `VM.Audit`
   - `VM.Config.Disk`
   - `Datastore.AllocateSpace`
   - `Datastore.Allocate`
2. **Proxmox CSI User**: A Proxmox user named `kubernetes-csi@pve` is created and assigned the `CSI` role.
3. **Proxmox CSI User Token**: An API token with the ID `CSI` is created for the `kubernetes-csi@pve` user.
4. **Proxmox CSI Namespace**: Namespaces are created for the Proxmox CSI plugin.
5. **Proxmox CSI Plugin Secret**: A secret is created with the Proxmox token for the Proxmox CSI plugin.

> **Note**: All VMs in the cluster must have the SCSI Controller set to `VirtIO SCSI single` or `VirtIO SCSI` type to be able to attach disks.

For more information, refer to the [Proxmox CSI Plugin Installation Guide](https://github.com/sergelogvinov/proxmox-csi-plugin/blob/main/docs/install.md).