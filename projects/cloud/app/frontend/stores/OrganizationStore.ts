import { ApolloClient } from '@apollo/client';
import { makeAutoObservable, runInAction } from 'mobx';
import {
  ChangeUserRoleDocument,
  OrganizationQuery,
  OrganizationDocument,
  Role,
} from '../graphql/types';

class OrganizationStore {
  organization: OrganizationQuery['organization'];

  client: ApolloClient<object>;

  constructor(client: ApolloClient<object>) {
    makeAutoObservable(this);
    this.client = client;
  }

  get members() {
    if (!this.organization) {
      return [];
    }
    return [...this.users, ...this.admins].sort(
      (first, second) => 0 - (first.name > second.name ? -1 : 1),
    );
  }

  get users() {
    if (!this.organization) {
      return [];
    }
    return this.organization.users.map((user) => {
      return {
        id: user.id,
        email: user.email,
        name: user.account.name,
        avatarUrl: user.avatarUrl ?? undefined,
        role: Role.User,
      };
    });
  }

  get admins() {
    if (!this.organization) {
      return [];
    }
    return this.organization.admins.map((user) => {
      return {
        id: user.id,
        email: user.email,
        name: user.account.name,
        avatarUrl: user.avatarUrl ?? undefined,
        role: Role.Admin,
      };
    });
  }

  async changeUserRole(memberId: string, newRole: Role) {
    if (!this.organization) {
      return;
    }
    await this.client.mutate({
      mutation: ChangeUserRoleDocument,
      variables: {
        input: {
          userId: memberId,
          organizationId: this.organization.id,
          role: newRole,
        },
      },
    });
    runInAction(() => {
      if (!this.organization) {
        return;
      }
      switch (newRole) {
        case Role.User:
          const adminIndex = this.organization.admins
            .map((admin) => admin.id)
            .indexOf(memberId);
          this.organization.users.push(
            this.organization.admins[adminIndex],
          );
          this.organization.admins.splice(adminIndex, 1);
          break;
        case Role.Admin:
          const userIndex = this.organization.users
            .map((user) => user.id)
            .indexOf(memberId);
          this.organization.admins.push(
            this.organization.users[userIndex],
          );
          this.organization.users.splice(userIndex, 1);
          break;
      }
    });
  }

  async load(organizationName: string) {
    const { data } = await this.client.query({
      query: OrganizationDocument,
      variables: { name: organizationName },
    });
    runInAction(() => {
      this.organization = data.organization;
    });
  }
}

export default OrganizationStore;
