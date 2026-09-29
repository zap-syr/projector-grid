<script lang="ts">
  import appIcon from '../../../assets/app_icon.png';

  let { size = 32 }: { size?: number } = $props();
</script>

<img src={appIcon} alt="" width={size} height={size} />

<style>
  img {
    flex: none;
    display: block;
  }
</style>
